
// Survivus – SwiftUI starter
// Single-file playground-style SwiftUI app scaffold
// Tabs: Results • Picks • Table
// Includes: data models, scoring engine, simple in‑memory store, mock data, and basic UI
// You can later swap Storage to Firebase/CloudKit.

import SwiftUI

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
