import SwiftUI

struct SelectPhaseSheet: View {
    @Environment(\.dismiss) private var dismiss

    let phases: [PickPhase]
    let currentPhaseID: PickPhase.ID?
    let lockedPhaseIDs: Set<PickPhase.ID>
    let onActivate: (PickPhase) -> Void
    let onModify: (PickPhase) -> Void
    let onDelete: (PickPhase) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if phases.isEmpty {
                    ContentUnavailableView(
                        "No phases",
                        systemImage: "tray",
                        description: Text("Create a new phase to activate it here.")
                    )
                } else {
                    List {
                        ForEach(phases) { phase in
                            PhaseRow(
                                phase: phase,
                                isActive: phase.id == currentPhaseID,
                                isEditable: !lockedPhaseIDs.contains(phase.id),
                                onActivate: {
                                    onActivate($0)
                                    dismiss()
                                },
                                onModify: onModify,
                                onDelete: onDelete
                            )
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Select Phase to Modify")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.fraction(0.8)])
        .presentationCornerRadius(28)
    }
}

private struct PhaseRow: View {
    let phase: PickPhase
    let isActive: Bool
    let isEditable: Bool
    let onActivate: (PickPhase) -> Void
    let onModify: (PickPhase) -> Void
    let onDelete: (PickPhase) -> Void

    var body: some View {
        Button {
            guard isEditable else { return }
            onModify(phase)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(phase.name)
                        .font(.headline)

                    if isActive {
                        Text("Active")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.15))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    if !isEditable {
                        LockPill(text: "Cannot be modified")
                    }
                }

                if !phase.categories.isEmpty {
                    Text("Categories: \(phase.categories.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                onDelete(phase)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                onActivate(phase)
            } label: {
                Label("Activate", systemImage: "checkmark.circle")
            }
            .tint(.blue)
        }
    }
}
