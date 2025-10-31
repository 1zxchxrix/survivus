import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct AdminRoomView: View {
    @EnvironmentObject var app: AppState
    @State private var isPresentingNewPhase = false
    @State private var isPresentingSelectPhase = false
    @State private var isPresentingStartWeek = false
    @State private var isPresentingManageContestants = false
    @State private var phaseBeingEdited: PickPhase?
    @State private var phaseForInsertingResults: PickPhase?
    @State private var selectedPhaseForNewWeekID: PickPhase.ID?

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Phase: \(currentPhase?.name ?? "None")")
                    Text("Current Week: \(currentWeekTitle)")
                }
            }

            Section("Week") {
                Button("Insert Results") {
                    if let phase = currentPhase, !phase.categories.isEmpty, currentWeekId != nil {
                        phaseForInsertingResults = phase
                    }
                }
                .disabled(!canInsertResults || !hasPhases)
                Button("Start New Week") {
                    selectedPhaseForNewWeekID = currentPhase?.id ?? phases.first?.id
                    isPresentingStartWeek = true
                }
                .disabled(!canStartNewWeek)
            }

            Section("Season") {
                Button("Phases") {
                    isPresentingSelectPhase = true
                }
                Button("Contestants") {
                    isPresentingManageContestants = true
                }
            }
        }
        .navigationTitle("Admin Room")
        .sheet(isPresented: $isPresentingStartWeek) {
            StartWeekSheet(
                phases: phases,
                selectedPhaseID: selectedPhaseForNewWeekID ?? currentPhase?.id,
                onStart: { phase in
                    selectedPhaseForNewWeekID = phase.id
                    startNewWeek(activating: phase)
                }
            )
        }
        .sheet(isPresented: $isPresentingSelectPhase) {
            SelectPhaseSheet(
                phases: phases,
                currentPhaseID: currentPhase?.id,
                lockedPhaseIDs: app.activatedPhaseIDs,
                onModify: { phase in
                    guard !app.hasPhaseEverBeenActive(phase.id) else { return }
                    phaseBeingEdited = phase
                    isPresentingSelectPhase = false
                },
                onDelete: { phase in
                    app.deletePhase(withId: phase.id)
                },
                onCreate: {
                    isPresentingSelectPhase = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        isPresentingNewPhase = true
                    }
                }
            )
        }
        .sheet(isPresented: $isPresentingNewPhase) {
            CreatePhaseSheet(phase: nil) { newPhase in
                handlePhaseSave(newPhase)
                isPresentingNewPhase = false
            }
            .presentationCornerRadius(28)
        }
        .sheet(isPresented: $isPresentingManageContestants) {
            ManageContestantsSheet(contestants: app.store.config.contestants) { contestants in
                app.updateContestants(contestants)
            }
        }
        .sheet(item: $phaseBeingEdited) { phase in
            CreatePhaseSheet(phase: phase) { updatedPhase in
                handlePhaseSave(updatedPhase)
                phaseBeingEdited = nil
            }
            .presentationCornerRadius(28)
        }
        .sheet(item: $phaseForInsertingResults) { phase in
            if let episodeId = currentWeekId {
                InsertResultsSheet(
                    phase: phase,
                    contestants: app.store.config.contestants,
                    episodeId: episodeId,
                    existingResult: currentWeekResult,
                    onSave: { result in
                        app.saveEpisodeResult(result)
                    }
                )
            } else {
                EmptyView()
            }
        }
    }
}

#Preview {
    NavigationStack {
        AdminRoomView()
            .environmentObject(AppState.preview)
    }
}

private extension AdminRoomView {
    var phases: [PickPhase] { app.phases }

    var currentPhase: PickPhase? {
        app.activePhase
    }

    var currentWeekTitle: String {
        guard let weekId = app.store.results.map(\.id).max() else {
            return "None"
        }

        if let episode = app.store.config.episodes.first(where: { $0.id == weekId }) {
            return episode.title
        }

        return "Week \(weekId)"
    }

    var canInsertResults: Bool {
        guard let phase = currentPhase, currentWeekId != nil else { return false }
        guard !hasResultsForCurrentWeek else { return false }
        return !phase.categories.isEmpty
    }

    var hasPhases: Bool {
        !phases.isEmpty
    }

    var canStartNewWeek: Bool {
        hasPhases && hasSubmittedResultsForCurrentWeek
    }

    var hasSubmittedResultsForCurrentWeek: Bool {
        guard let latestResult = app.store.results.max(by: { $0.id < $1.id }) else {
            return true
        }

        return latestResult.hasRecordedResults
    }

    var currentWeekId: Int? {
        app.store.results.map(\.id).max()
    }

    var currentWeekResult: EpisodeResult? {
        guard let currentWeekId else { return nil }
        return app.store.results.first(where: { $0.id == currentWeekId })
    }

    var hasResultsForCurrentWeek: Bool {
        currentWeekResult?.hasRecordedResults ?? false
    }

    func startNewWeek(activating phase: PickPhase) {
        app.startNewWeek(activating: phase)
    }

    func handlePhaseSave(_ phase: PickPhase) {
        let isUpdatingExisting = app.phases.contains(where: { $0.id == phase.id })
        if isUpdatingExisting {
            guard !app.hasPhaseEverBeenActive(phase.id) else { return }
        }

        app.savePhase(phase)

        if app.activePhaseId == phase.id {
            app.activePhaseId = nil
        }
    }
}

private struct AdaptiveFractionalSheetDetentModifier: ViewModifier {
    let defaultFraction: CGFloat
    let iPadFraction: CGFloat

    private var resolvedFraction: CGFloat {
#if canImport(UIKit)
        if UIDevice.current.userInterfaceIdiom == .pad {
            return iPadFraction
        }
#endif
        return defaultFraction
    }

    func body(content: Content) -> some View {
        content.presentationDetents([.fraction(resolvedFraction)])
    }
}

