import SwiftUI

struct StartWeekSheet: View {
    @Environment(\.dismiss) private var dismiss

    let phases: [PickPhase]
    let onStart: (PickPhase) -> Void

    @State private var selectedPhaseID: PickPhase.ID?

    init(phases: [PickPhase], selectedPhaseID: PickPhase.ID?, onStart: @escaping (PickPhase) -> Void) {
        self.phases = phases
        self.onStart = onStart
        _selectedPhaseID = State(initialValue: selectedPhaseID ?? phases.first?.id)
    }

    var body: some View {
        NavigationStack {
            Group {
                if phases.isEmpty {
                    ContentUnavailableView(
                        "No phases",
                        systemImage: "tray",
                        description: Text("Create a phase before starting a new week.")
                    )
                } else {
                    Form {
                        Section("Phase") {
                            Picker("Phase", selection: $selectedPhaseID) {
                                ForEach(phases) { phase in
                                    Text(phase.name).tag(Optional(phase.id))
                                }
                            }
                            .pickerStyle(.wheel)
                        }
                    }
                }
            }
            .navigationTitle("Start New Week")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        if let id = selectedPhaseID,
                           let phase = phases.first(where: { $0.id == id }) {
                            onStart(phase)
                        }
                        dismiss()
                    }
                    .disabled(selectedPhaseID == nil)
                }
            }
        }
        .adaptivePresentationDetents(defaultFraction: 0.4, iPadFraction: 0.6)
        .presentationCornerRadius(28)
        .onAppear {
            if selectedPhaseID == nil {
                selectedPhaseID = phases.first?.id
            }
        }
    }
}
