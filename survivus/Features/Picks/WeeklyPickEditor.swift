import SwiftUI

enum WeeklyPickPanel: Hashable {
    case remain
    case votedOut
    case immunity
}

struct WeeklyPickEditor: View {
    @EnvironmentObject var app: AppState
    let episode: Episode
    let panel: WeeklyPickPanel
    @State private var picks: WeeklyPicks

    init(episode: Episode, panel: WeeklyPickPanel) {
        self.episode = episode
        self.panel = panel
        _picks = State(initialValue: WeeklyPicks(userId: "", episodeId: episode.id))
    }

    var body: some View {
        let config = app.store.config
        let userId = app.currentUserId
        let phase = app.scoring.phase(for: episode)
        let caps = (phase == .preMerge) ? config.weeklyPickCapsPreMerge : config.weeklyPickCapsPostMerge
        let limit = phaseCategoryLimit(for: panel) ?? selectionLimit(for: panel, caps: caps)
        let locked = picksLocked(for: episode)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if locked {
                    LockPill(text: "Locked for \(episode.title)")
                } else {
                    Text(instructionText(for: panel, limit: limit))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                LimitedMultiSelect(
                    all: config.contestants,
                    selection: Binding(
                        get: { selection(for: panel) },
                        set: { newValue in updateSelection(newValue, limit: limit, locked: locked) }
                    ),
                    max: limit,
                    disabled: locked
                )
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(navigationTitle(for: panel))
        .onAppear { loadPicks(for: userId) }
        .onChange(of: episode.id) { _ in loadPicks(for: userId) }
        .onChange(of: app.currentUserId) { newValue in loadPicks(for: newValue) }
    }

    private func loadPicks(for userId: String) {
        picks = app.store.picks(for: userId, episodeId: episode.id)
    }

    private func selection(for panel: WeeklyPickPanel) -> Set<String> {
        switch panel {
        case .remain:
            return picks.remain
        case .votedOut:
            return picks.votedOut
        case .immunity:
            return picks.immunity
        }
    }

    private func updateSelection(_ newValue: Set<String>, limit: Int, locked: Bool) {
        guard !locked else { return }
        let limited = Set(newValue.prefix(limit))
        switch panel {
        case .remain:
            picks.remain = limited
        case .votedOut:
            picks.votedOut = limited
        case .immunity:
            picks.immunity = limited
        }
        app.store.save(picks)
    }

    private func selectionLimit(for panel: WeeklyPickPanel, caps: SeasonConfig.WeeklyPickCaps) -> Int {
        switch panel {
        case .remain:
            return caps.remain ?? 3
        case .votedOut:
            return caps.votedOut ?? 3
        case .immunity:
            return caps.immunity ?? 3
        }
    }

    private func phaseCategoryLimit(for panel: WeeklyPickPanel) -> Int? {
        guard let categories = app.activePhase?.categories else { return nil }

        let matchingCategory: PickPhase.Category?

        switch panel {
        case .remain:
            matchingCategory = categories.first(where: { $0.matchesRemainCategory })
        case .votedOut:
            matchingCategory = categories.first(where: { $0.matchesVotedOutCategory })
        case .immunity:
            matchingCategory = categories.first(where: { $0.matchesImmunityCategory })
        }

        guard let total = matchingCategory?.totalPicks, total > 0 else { return nil }
        return total
    }

    private func navigationTitle(for panel: WeeklyPickPanel) -> String {
        switch panel {
        case .remain:
            return "Who Will Remain"
        case .votedOut:
            return "Who Will be Voted Out"
        case .immunity:
            return "Who Will Have Immunity"
        }
    }

    private func instructionText(for panel: WeeklyPickPanel, limit: Int) -> String {
        switch panel {
        case .remain:
            return "Select up to \(limit) players you expect to stay safe this week."
        case .votedOut:
            return "Select up to \(limit) players you think will be voted out."
        case .immunity:
            return "Select up to \(limit) players you think will win immunity."
        }
    }
}
