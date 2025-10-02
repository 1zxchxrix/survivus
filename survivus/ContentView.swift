// Survivus – SwiftUI starter
// Single-file playground-style SwiftUI app scaffold
// Tabs: Results • Picks • Table
// Includes: data models, scoring engine, simple in‑memory store, mock data, and basic UI
// You can later swap Storage to Firebase/CloudKit.

import SwiftUI

// MARK: - Core Models

struct Contestant: Identifiable, Hashable, Codable {
    let id: String // stable id (e.g., "s47_c01")
    var name: String
    var tribe: String?
}

struct Episode: Identifiable, Hashable, Codable { // Week == Episode
    let id: Int // 1-based index for simplicity
    var airDate: Date
    var title: String
    var isMergeEpisode: Bool
}

enum Phase: String, Codable { case preMerge, postMerge }

struct EpisodeResult: Identifiable, Hashable, Codable {
    let id: Int // episode id
    var immunityWinners: [String] // contestant ids (could be team or individual depending on phase)
    var votedOut: [String] // contestant ids eliminated this episode (handle medevac/quit under same)
}

// User picks per-episode (except "merge picks" which are set once)
struct WeeklyPicks: Identifiable, Hashable, Codable {
    var id: String { "\(userId)-ep-\(episodeId)" }
    let userId: String
    let episodeId: Int
    var remain: Set<String> = [] // up to 3 pre-merge; might change post-merge if you choose to cap differently
    var votedOut: Set<String> = [] // up to 3; may reduce later in season
    var immunity: Set<String> = [] // up to 3 pre-merge; TBD post-merge dynamic count
}

// One-time season picks
struct SeasonPicks: Identifiable, Hashable, Codable {
    var id: String { "\(userId)-season" }
    let userId: String
    var mergePicks: Set<String> = [] // three, immutable after Episode 1 starts
    var finalThreePicks: Set<String> = [] // chosen after merge
    var winnerPick: String? // chosen after Final Three is set
}

struct UserProfile: Identifiable, Hashable, Codable {
    let id: String // user id
    var displayName: String
}

struct UserScoreBreakdown: Identifiable, Hashable, Codable {
    var id: String { userId }
    let userId: String
    var weeksParticipated: Int
    var votedOutPoints: Int
    var remainPoints: Int
    var immunityPoints: Int
    var mergeTrackPoints: Int // "Who will make the merge" (1 pt per episode per still-alive pick)
    var finalThreeTrackPoints: Int // 1 pt per episode per still-alive F3 pick
    var winnerPoints: Int // 5 pts if predicted winner
    var total: Int { votedOutPoints + remainPoints + immunityPoints + mergeTrackPoints + finalThreeTrackPoints + winnerPoints }
}

// MARK: - Season Config (tweak per season)

struct SeasonConfig: Codable {
    struct WeeklyPickCaps: Codable {
        var remain: Int?
        var votedOut: Int?
        var immunity: Int?
    }
    var seasonId: String
    var name: String
    var contestants: [Contestant]
    var episodes: [Episode]
    var weeklyPickCapsPreMerge: WeeklyPickCaps = .init(remain: 3, votedOut: 3, immunity: 3)
    var weeklyPickCapsPostMerge: WeeklyPickCaps = .init(remain: 3, votedOut: 3, immunity: nil) // nil means dynamic; e.g. set when known
    var lockHourUTC: Int = 23 // lock picks at 23:00 UTC on air day (tweak)
}

// MARK: - Scoring Engine

struct ScoringEngine {
    let config: SeasonConfig
    let resultsByEpisode: [Int: EpisodeResult]

    func phase(for episode: Episode) -> Phase {
        // If the episode is marked merge or is after merge, treat as post-merge.
        if episode.isMergeEpisode { return .postMerge }
        // Alternatively: compute if any episode <= current had isMergeEpisode == true
        let merged = config.episodes.contains(where: { $0.id <= episode.id && $0.isMergeEpisode })
        return merged ? .postMerge : .preMerge
    }

    // Points: VotedOut(3), Remain(1), Immunity(pre:1, post:3)
    func score(weekly: WeeklyPicks, episode: Episode) -> (votedOut: Int, remain: Int, immunity: Int) {
        guard let result = resultsByEpisode[episode.id] else { return (0,0,0) }
        let votedOutHits = weekly.votedOut.intersection(result.votedOut).count
        let remainHits = weekly.remain.filter { !result.votedOut.contains($0) }.count
        let immunityHits = weekly.immunity.intersection(result.immunityWinners).count
        let phase = phase(for: episode)
        let immunityPts = (phase == .preMerge) ? immunityHits * 1 : immunityHits * 3
        return (votedOutHits * 3, remainHits * 1, immunityPts)
    }

    // Merge-tracker: 1 pt per episode for each pick still alive
    func mergeTrackPoints(for userId: String, upTo episodeId: Int, seasonPicks: SeasonPicks) -> Int {
        guard !seasonPicks.mergePicks.isEmpty else { return 0 }
        var pts = 0
        for ep in config.episodes where ep.id <= episodeId {
            if let res = resultsByEpisode[ep.id] {
                let alive = seasonPicks.mergePicks.subtracting(res.votedOut)
                pts += alive.count // 1 per alive pick per episode
            }
        }
        return pts
    }

    // Final Three tracker: 1 pt per episode for each F3 pick still alive (after merge)
    func finalThreeTrackPoints(for userId: String, upTo episodeId: Int, seasonPicks: SeasonPicks) -> Int {
        guard !seasonPicks.finalThreePicks.isEmpty else { return 0 }
        var pts = 0
        for ep in config.episodes where ep.id <= episodeId {
            if let res = resultsByEpisode[ep.id] {
                let alive = seasonPicks.finalThreePicks.subtracting(res.votedOut)
                pts += alive.count
            }
        }
        return pts
    }

    // Winner points: award 5 if winnerPick matches last remaining
    func winnerPoints(seasonPicks: SeasonPicks, finalResult: EpisodeResult?) -> Int {
        // A simplistic approach: once we know the sole survivor id, compare.
        // In practice, you may compute from the final EpisodeResult where votedOut leaves 1 remaining.
        guard let winnerId = soleSurvivorId(finalResult: finalResult), let pick = seasonPicks.winnerPick else { return 0 }
        return (winnerId == pick) ? 5 : 0
    }

    func soleSurvivorId(finalResult: EpisodeResult?) -> String? {
        // Placeholder: in a real system you'd derive the ultimate survivor from all results.
        return nil
    }
}

// MARK: - Storage (In-Memory Mock)

final class MemoryStore: ObservableObject {
    @Published var config: SeasonConfig
    @Published var results: [EpisodeResult]
    @Published var users: [UserProfile]
    @Published var seasonPicks: [String: SeasonPicks] // userId -> season picks
    @Published var weeklyPicks: [String: [Int: WeeklyPicks]] // userId -> (episodeId -> picks)

    init(config: SeasonConfig, results: [EpisodeResult], users: [UserProfile]) {
        self.config = config
        self.results = results
        self.users = users
        self.seasonPicks = Dictionary(uniqueKeysWithValues: users.map { ($0.id, SeasonPicks(userId: $0.id)) })
        self.weeklyPicks = Dictionary(uniqueKeysWithValues: users.map { ($0.id, [:]) })
    }

    var resultsByEpisode: [Int: EpisodeResult] { Dictionary(uniqueKeysWithValues: results.map { ($0.id, $0) }) }

    func picks(for userId: String, episodeId: Int) -> WeeklyPicks {
        if let p = weeklyPicks[userId]?[episodeId] { return p }
        let p = WeeklyPicks(userId: userId, episodeId: episodeId)
        weeklyPicks[userId, default: [:]][episodeId] = p
        return p
    }

    func save(_ picks: WeeklyPicks) {
        weeklyPicks[picks.userId, default: [:]][picks.episodeId] = picks
        objectWillChange.send()
    }
}

// MARK: - Mock Data

extension SeasonConfig {
    static func mock() -> SeasonConfig {
        let contestants: [Contestant] = [
            .init(id: "c01", name: "Alex"), .init(id: "c02", name: "Bailey"), .init(id: "c03", name: "Casey"),
            .init(id: "c04", name: "Drew"), .init(id: "c05", name: "Eden"), .init(id: "c06", name: "Finn"),
            .init(id: "c07", name: "Gray"), .init(id: "c08", name: "Harper"), .init(id: "c09", name: "Indy"),
            .init(id: "c10", name: "Jules"), .init(id: "c11", name: "Kai"), .init(id: "c12", name: "Lane")
        ]
        let base = Date()
        let episodes = (1...12).map { i in
            Episode(id: i, airDate: Calendar.current.date(byAdding: .day, value: 7*(i-1), to: base)!, title: "Week \(i)", isMergeEpisode: i == 7)
        }
        return SeasonConfig(seasonId: "S00", name: "Mock Season", contestants: contestants, episodes: episodes)
    }
}

extension EpisodeResult {
    static func mock(episodeId: Int) -> EpisodeResult {
        // For demo: rotate immunity & votedOut naively
        let imm = ["c0\(((episodeId-1)%3)+1)"]
        let out = episodeId <= 10 ? ["c0\(((episodeId)%12)+1)"] : [] // last eps no elimination in mock
        return EpisodeResult(id: episodeId, immunityWinners: imm, votedOut: out)
    }
}

// MARK: - App State

@MainActor
final class AppState: ObservableObject {
    @Published var store: MemoryStore
    @Published var currentUserId: String

    init() {
        let cfg = SeasonConfig.mock()
        let results = cfg.episodes.map { EpisodeResult.mock(episodeId: $0.id) }
        let users = [UserProfile(id: "u1", displayName: "Zac"), UserProfile(id: "u2", displayName: "Sam")] // demo
        self.store = MemoryStore(config: cfg, results: results, users: users)
        self.currentUserId = users.first!.id
    }

    var scoring: ScoringEngine { ScoringEngine(config: store.config, resultsByEpisode: store.resultsByEpisode) }
}

// MARK: - UI

struct SurvivusApp: App {
    @StateObject private var app = AppState()

    var body: some Scene {
        WindowGroup {
            TabView {
                ResultsView()
                    .environmentObject(app)
                    .tabItem { Label("Results", systemImage: "list.bullet.rectangle") }
                PicksView()
                    .environmentObject(app)
                    .tabItem { Label("Picks", systemImage: "checkmark.square") }
                TableView()
                    .environmentObject(app)
                    .tabItem { Label("Table", systemImage: "tablecells") }
            }
        }
    }
}

// MARK: - Results Tab

struct ResultsView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        NavigationStack {
            List(app.store.config.episodes) { ep in
                let result = app.store.resultsByEpisode[ep.id]
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(ep.title).font(.headline)
                        if ep.isMergeEpisode { Text("MERGE").font(.caption2).padding(4).background(.yellow.opacity(0.3)).clipShape(RoundedRectangle(cornerRadius: 6)) }
                        Spacer()
                        Text(ep.airDate, style: .date).foregroundStyle(.secondary)
                    }
                    if let r = result {
                        if !r.immunityWinners.isEmpty {
                            Text("Immunity: " + r.immunityWinners.compactMap { id in app.store.config.contestants.first { $0.id == id }?.name }.joined(separator: ", "))
                        }
                        if !r.votedOut.isEmpty {
                            Text("Voted out: " + r.votedOut.compactMap { id in app.store.config.contestants.first { $0.id == id }?.name }.joined(separator: ", "))
                        }
                    } else {
                        Text("No result yet").foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Results")
        }
    }
}

// MARK: - Picks Tab

struct PicksView: View {
    @EnvironmentObject var app: AppState
    @State private var selectedEpisode: Episode?

    var body: some View {
        NavigationStack {
            Form {
                Section("Season Picks") {
                    MergePickEditor()
                    FinalThreePickEditor()
                    WinnerPickEditor()
                }

                Section("Weekly Picks") {
                    Picker("Episode", selection: Binding(
                        get: { selectedEpisode?.id ?? app.store.config.episodes.first?.id ?? 1 },
                        set: { newId in selectedEpisode = app.store.config.episodes.first(where: { $0.id == newId }) }
                    )) {
                        ForEach(app.store.config.episodes) { ep in
                            Text(ep.title).tag(ep.id)
                        }
                    }
                    if let ep = app.store.config.episodes.first(where: { $0.id == (selectedEpisode?.id ?? app.store.config.episodes.first!.id) }) {
                        WeeklyPickEditor(episode: ep)
                    }
                }
            }
            .onAppear { if selectedEpisode == nil { selectedEpisode = app.store.config.episodes.first } }
            .navigationTitle("Picks")
        }
    }
}

// MARK: - Merge Picks Editor

struct MergePickEditor: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        let cfg = app.store.config
        let userId = app.currentUserId
        let disabled = picksLocked(for: cfg.episodes.first)
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text("Who Will Make the Merge (3)").font(.headline); if disabled { LockPill() } }
            LimitedMultiSelect(
                all: cfg.contestants,
                selection: Binding(
                    get: { app.store.seasonPicks[userId]?.mergePicks ?? [] },
                    set: { new in app.store.seasonPicks[userId]?.mergePicks = Set(new.prefix(3)) }
                ),
                max: 3,
                disabled: disabled
            )
        }
    }
}

// MARK: - Final Three Picks Editor

struct FinalThreePickEditor: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        let cfg = app.store.config
        let userId = app.currentUserId
        // Enable after merge episode
        let afterMerge = cfg.episodes.contains(where: { $0.isMergeEpisode })
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text("Final Three Picks (3)").font(.headline); if !afterMerge { Text("(Available after merge)").foregroundStyle(.secondary) } }
            LimitedMultiSelect(
                all: cfg.contestants,
                selection: Binding(
                    get: { app.store.seasonPicks[userId]?.finalThreePicks ?? [] },
                    set: { new in app.store.seasonPicks[userId]?.finalThreePicks = Set(new.prefix(3)) }
                ),
                max: 3,
                disabled: !afterMerge
            )
        }
    }
}

// MARK: - Winner Pick Editor

struct WinnerPickEditor: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        let cfg = app.store.config
        let userId = app.currentUserId
        // Enable after Final Three determined (simplified: after last episode - 1)
        let enable = cfg.episodes.count >= 2
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text("Sole Survivor (1)").font(.headline); if !enable { Text("(Available after Final Three)").foregroundStyle(.secondary) } }
            Picker("Winner", selection: Binding(
                get: { app.store.seasonPicks[userId]?.winnerPick ?? "" },
                set: { app.store.seasonPicks[userId]?.winnerPick = $0.isEmpty ? nil : $0 }
            )) {
                Text("—").tag("")
                ForEach(app.store.config.contestants) { c in Text(c.name).tag(c.id) }
            }
            .disabled(!enable)
        }
    }
}

// MARK: - Weekly Picks Editor

struct WeeklyPickEditor: View {
    @EnvironmentObject var app: AppState
    let episode: Episode

    var body: some View {
        let cfg = app.store.config
        let userId = app.currentUserId
        let phase = app.scoring.phase(for: episode)
        let caps = (phase == .preMerge) ? cfg.weeklyPickCapsPreMerge : cfg.weeklyPickCapsPostMerge
        let locked = picksLocked(for: episode)

        @State var picks = app.store.picks(for: userId, episodeId: episode.id)

        VStack(alignment: .leading, spacing: 16) {
            if locked { LockPill(text: "Locked for \(episode.title)") }

            Group {
                Text("Who Will Remain (\(caps.remain ?? 3))").font(.headline)
                LimitedMultiSelect(all: cfg.contestants, selection: Binding(
                    get: { picks.remain },
                    set: { picks.remain = Set($0.prefix(caps.remain ?? 3)) }
                ), max: caps.remain ?? 3, disabled: locked)
            }

            Group {
                Text("Who Will be Voted Out (\(caps.votedOut ?? 3))").font(.headline)
                LimitedMultiSelect(all: cfg.contestants, selection: Binding(
                    get: { picks.votedOut },
                    set: { picks.votedOut = Set($0.prefix(caps.votedOut ?? 3)) }
                ), max: caps.votedOut ?? 3, disabled: locked)
            }

            Group {
                let immCap = (phase == .preMerge) ? (caps.immunity ?? 3) : (caps.immunity ?? 3) // post-merge may become dynamic
                Text("Who Will Have Immunity (\(immCap))").font(.headline)
                LimitedMultiSelect(all: cfg.contestants, selection: Binding(
                    get: { picks.immunity },
                    set: { picks.immunity = Set($0.prefix(immCap)) }
                ), max: immCap, disabled: locked)
            }

            HStack {
                Spacer()
                Button("Save Picks") { app.store.save(picks) }.disabled(locked)
            }
        }
        .onChange(of: episode.id) { _ in
            var p = app.store.picks(for: userId, episodeId: episode.id)
            picks = p
        }
    }
}

// MARK: - Table Tab

struct TableView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        let cfg = app.store.config
        let scoring = app.scoring
        // Compute scores up to the latest episode with results
        let lastEp = app.store.results.map { $0.id }.max() ?? 0

        let breakdowns: [UserScoreBreakdown] = app.store.users.map { user in
            var votedOutPts = 0, remainPts = 0, immunityPts = 0, weeks = 0
            for ep in cfg.episodes where ep.id <= lastEp {
                let p = app.store.weeklyPicks[user.id]?[ep.id]
                if let p { weeks += 1; let s = scoring.score(weekly: p, episode: ep); votedOutPts += s.votedOut; remainPts += s.remain; immunityPts += s.immunity }
            }
            let season = app.store.seasonPicks[user.id] ?? SeasonPicks(userId: user.id)
            let mergePts = scoring.mergeTrackPoints(for: user.id, upTo: lastEp, seasonPicks: season)
            let f3Pts = scoring.finalThreeTrackPoints(for: user.id, upTo: lastEp, seasonPicks: season)
            let winnerPts = scoring.winnerPoints(seasonPicks: season, finalResult: nil)
            return UserScoreBreakdown(userId: user.id, weeksParticipated: weeks, votedOutPoints: votedOutPts, remainPoints: remainPts, immunityPoints: immunityPts, mergeTrackPoints: mergePts, finalThreeTrackPoints: f3Pts, winnerPoints: winnerPts)
        }
        .sorted { $0.total > $1.total }

        return NavigationStack {
            List {
                TableHeader()
                ForEach(breakdowns) { b in
                    HStack {
                        Text(app.store.users.first(where: { $0.id == b.userId })?.displayName ?? b.userId)
                        Spacer()
                        Text("\(b.weeksParticipated)").frame(width: 32)
                        Text("\(b.votedOutPoints)").frame(width: 40)
                        Text("\(b.remainPoints)").frame(width: 40)
                        Text("\(b.immunityPoints)").frame(width: 40)
                        Text("\(b.total)").fontWeight(.semibold).frame(width: 50, alignment: .trailing)
                    }
                }
            }
            .navigationTitle("Table")
        }
    }
}

struct TableHeader: View {
    var body: some View {
        HStack {
            Text("Name").fontWeight(.semibold)
            Spacer()
            Text("Wk").frame(width: 32)
            Text("VO").frame(width: 40)
            Text("RM").frame(width: 40)
            Text("IM").frame(width: 40)
            Text("Total").frame(width: 50, alignment: .trailing)
        }
        .foregroundStyle(.secondary)
    }
}

// MARK: - Reusable UI

struct LimitedMultiSelect: View {
    let all: [Contestant]
    @Binding var selection: Set<String>
    let max: Int
    var disabled: Bool = false

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
            ForEach(all) { c in
                let isOn = selection.contains(c.id)
                Button {
                    guard !disabled else { return }
                    if isOn { selection.remove(c.id) }
                    else if selection.count < max { selection.insert(c.id) }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                        Text(c.name).lineLimit(1)
                    }
                    .padding(.vertical, 8).padding(.horizontal, 10)
                    .frame(maxWidth: .infinity)
                    .background(isOn ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct LockPill: View {
    var text: String = "Locked"
    var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.vertical, 4).padding(.horizontal, 8)
            .background(Color.red.opacity(0.15))
            .clipShape(Capsule())
    }
}

// MARK: - Utilities

func picksLocked(for episode: Episode?) -> Bool {
    guard let ep = episode else { return true }
    // Demo lock: disable once airDate has passed
    return Date() >= ep.airDate
}
