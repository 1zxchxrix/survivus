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
            .navigationTitle("Phases")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
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
                        .font(.title3)

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

                // ⬇️ Replace your "Categories: N" with this
                if !phase.categories.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(phase.categories) { category in
                            CategoryDisclosureRow(category: category)
                                .padding(.vertical, 4)
                            Divider().opacity(0.15)
                        }
                    }
                    .padding(.top, 4)
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


// MARK: - Expandable category row

private struct CategoryDisclosureRow: View {
    let category: PickPhase.Category
    @State private var isExpanded: Bool = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                KeyValueRow(title: "Column ID", value: normalizedColumnId(category.columnId))
                KeyValueRow(title: "Total picks", value: String(category.totalPicks))

                if let p = category.pointsPerCorrectPick {
                    KeyValueRow(title: "Points per pick", value: "\(p)")
                }
                if let w = category.wagerPoints {
                    KeyValueRow(title: "Wager (±)", value: "±\(w)")
                }
            }
            .padding(.vertical, 4)
        } label: {
            HStack(spacing: 8) {
                Text(category.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                     ? "Untitled Category" : category.name)
                    .foregroundStyle(.primary)
                    .fontWeight(.semibold)
                Spacer()
                if category.autoScoresRemainingContestants { MiniTag(text: "Auto-score") }
                if category.isLocked { MiniTag(text: "Locked") }
            }
        }
        .animation(nil, value: isExpanded)
    }

    private func normalizedColumnId(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return trimmed.isEmpty ? "—" : trimmed
    }
}

// MARK: - Small UI helpers

private struct KeyValueRow: View {
    let title: String
    let value: String
    var body: some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
        .font(.subheadline)
    }
}

private struct MiniTag: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.vertical, 2)
            .padding(.horizontal, 6)
            .background(Color(.tertiarySystemFill))
            .clipShape(Capsule())
    }
}
