import SwiftUI

struct AdminRoomView: View {
    @State private var isPresentingCreatePhase = false

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Phase: Pre-merge")
                    Text("Current Week: 2")
                }
            }

            Section("Week") {
                Button("Insert Results") {}
                Button("Modify Previous Results") {}
                Button("Start New Week") {}
            }

            Section("Phase") {
                Button("Select Current Phase") {}
                Button("Create New Phase") {
                    isPresentingCreatePhase = true
                }
                Button("Remove Phase") {}
            }
        }
        .navigationTitle("Admin Room")
        .sheet(isPresented: $isPresentingCreatePhase) {
            CreatePhaseSheet()
                .presentationDetents([.fraction(0.8)])
                .presentationCornerRadius(28)
        }
    }
}

#Preview {
    NavigationStack {
        AdminRoomView()
    }
}

private struct CreatePhaseSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var phaseName = ""
    @State private var categories: [CategoryDraft] = []
    @State private var isPresentingAddCategory = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Phase name", text: $phaseName)
                }

                if !categories.isEmpty {
                    Section("Categories") {
                        ForEach(categories) { category in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(category.name.isEmpty ? "Untitled Category" : category.name)
                                    .font(.headline)

                                HStack {
                                    Text("Total picks: \(category.totalPicks)")
                                    if let points = category.pointsPerCorrectPick {
                                        Text("Points per correct pick: \(points)")
                                    }
                                }
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                                if category.isLocked {
                                    Text("Locked")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Section {
                    Button {
                        isPresentingAddCategory = true
                    } label: {
                        Label("Add category", systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationTitle("Create Phase")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isPresentingAddCategory) {
                AddCategorySheet { category in
                    categories.append(category)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    dismiss()
                } label: {
                    Text("Save")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 24)
                .background(Color(.systemGroupedBackground))
            }
        }
    }
}

private struct AddCategorySheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var categoryName = ""
    @State private var totalPicks = 1
    @State private var pointsPerCorrectPick: Int? = nil
    @State private var lockCategory = false

    var onAdd: (CategoryDraft) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Category") {
                    TextField("Category", text: $categoryName)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Total picks")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Picker("Total picks", selection: $totalPicks) {
                            ForEach(1...5, id: \.self) { value in
                                Text("\(value)")
                                    .tag(value)
                            }
                        }
                        .pickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 150)
                    }

                    TextField("Points per correct pick", value: $pointsPerCorrectPick, format: .number)
                        .keyboardType(.numberPad)
                }

                Section {
                    Toggle("Lock category", isOn: $lockCategory)
                }
            }
            .navigationTitle("Add Category")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button {
                    onAdd(
                        CategoryDraft(
                            name: categoryName,
                            totalPicks: totalPicks,
                            pointsPerCorrectPick: pointsPerCorrectPick,
                            isLocked: lockCategory
                        )
                    )
                    dismiss()
                } label: {
                    Text("Add category")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 24)
                .background(Color(.systemGroupedBackground))
            }
        }
    }
}

private struct CategoryDraft: Identifiable {
    let id = UUID()
    var name: String
    var totalPicks: Int
    var pointsPerCorrectPick: Int?
    var isLocked: Bool
}
