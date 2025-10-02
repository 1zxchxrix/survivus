import SwiftUI

struct WeeklyPickEditor: View {
    @EnvironmentObject var app: AppState
    let episode: Episode
    @Binding var expandedPanel: WeeklyPickPanel?
    let collapseSeasonPanels: () -> Void
    @State private var picks: WeeklyPicks

    init(episode: Episode, expandedPanel: Binding<WeeklyPickPanel?>, collapseSeasonPanels: @escaping () -> Void) {
        self.episode = episode
        self._expandedPanel = expandedPanel
        self.collapseSeasonPanels = collapseSeasonPanels
        _picks = State(initialValue: WeeklyPicks(userId: "", episodeId: episode.id))
    }

    var body: some View {
        let config = app.store.config
        let userId = app.currentUserId
        let phase = app.scoring.phase(for: episode)
        let caps = (phase == .preMerge) ? config.weeklyPickCapsPreMerge : config.weeklyPickCapsPostMerge
        let locked = picksLocked(for: episode)
        let remainCap = caps.remain ?? 3
        let votedOutCap = caps.votedOut ?? 3
        let immunityCap = caps.immunity ?? 3

        VStack(alignment: .leading, spacing: 16) {
            if locked {
                LockPill(text: "Locked for \(episode.title)")
            }

            DisclosureGroup(isExpanded: binding(for: .remain)) {
                LimitedMultiSelect(
                    all: config.contestants,
                    selection: Binding(
                        get: { picks.remain },
                        set: { picks.remain = Set($0.prefix(remainCap)) }
                    ),
                    max: remainCap,
                    disabled: locked
                )
                .padding(.top, 4)
            } label: {
                Text("Who Will Remain (\(remainCap))")
                    .font(.headline)
            }

            DisclosureGroup(isExpanded: binding(for: .votedOut)) {
                LimitedMultiSelect(
                    all: config.contestants,
                    selection: Binding(
                        get: { picks.votedOut },
                        set: { picks.votedOut = Set($0.prefix(votedOutCap)) }
                    ),
                    max: votedOutCap,
                    disabled: locked
                )
                .padding(.top, 4)
            } label: {
                Text("Who Will be Voted Out (\(votedOutCap))")
                    .font(.headline)
            }

            DisclosureGroup(isExpanded: binding(for: .immunity)) {
                LimitedMultiSelect(
                    all: config.contestants,
                    selection: Binding(
                        get: { picks.immunity },
                        set: { picks.immunity = Set($0.prefix(immunityCap)) }
                    ),
                    max: immunityCap,
                    disabled: locked
                )
                .padding(.top, 4)
            } label: {
                Text("Who Will Have Immunity (\(immunityCap))")
                    .font(.headline)
            }

            HStack {
                Spacer()
                Button("Save Picks") { app.store.save(picks) }
                    .disabled(locked)
            }
        }
        .onAppear { loadPicks(for: userId) }
        .onChange(of: episode.id) { _ in loadPicks(for: userId) }
        .onChange(of: app.currentUserId) { newValue in loadPicks(for: newValue) }
    }

    private func loadPicks(for userId: String) {
        picks = app.store.picks(for: userId, episodeId: episode.id)
    }

    private func binding(for panel: WeeklyPickPanel) -> Binding<Bool> {
        Binding(
            get: { expandedPanel == panel },
            set: { newValue in
                if newValue {
                    collapseSeasonPanels()
                    expandedPanel = panel
                } else if expandedPanel == panel {
                    expandedPanel = nil
                }
            }
        )
    }
}

enum WeeklyPickPanel: Hashable {
    case remain
    case votedOut
    case immunity
}
