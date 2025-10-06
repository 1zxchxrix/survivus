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
    @State private var category = ""
    @State private var totalPicks = 1
    @State private var pointsPerCorrectPick: Int? = nil
    @State private var lockCategory = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Phase name", text: $phaseName)
                    TextField("Category", text: $category)

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
            .navigationTitle("Create Phase")
            .navigationBarTitleDisplayMode(.inline)
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
