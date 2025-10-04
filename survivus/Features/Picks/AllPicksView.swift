import SwiftUI

struct AllPicksView: View {
    @EnvironmentObject var app: AppState
    @State private var selectedWeekId: Int = 1

    private var weekOptions: [WeekOption] {
        app.store.config.episodes
            .filter { $0.id <= 2 }
            .map { WeekOption(id: $0.id, title: $0.title) }
            .sorted { $0.id < $1.id }
    }

    private var contestantsById: [String: Contestant] {
        Dictionary(uniqueKeysWithValues: app.store.config.contestants.map { ($0.id, $0) })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    weekPicker
                        .padding(.bottom, 8)

                    ForEach(app.store.users) { user in
                        UserPicksCard(
                            user: user,
                            seasonPicks: app.store.seasonPicks[user.id],
                            weeklyPicks: app.store.weeklyPicks[user.id]?[selectedWeekId],
                            contestantsById: contestantsById
                        )
                    }
                }
                .padding()
            }
            .onAppear {
                if let firstWeek = weekOptions.first {
                    selectedWeekId = firstWeek.id
                }
            }
            .navigationTitle("Picks")
        }
    }

    private var weekPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Week")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Picker("Week", selection: $selectedWeekId) {
                ForEach(weekOptions) { option in
                    Text(option.title)
                        .tag(option.id)
                }
            }
            .pickerStyle(.menu)
        }
    }
}

private struct UserPicksCard: View {
    let user: UserProfile
    let seasonPicks: SeasonPicks?
    let weeklyPicks: WeeklyPicks?
    let contestantsById: [String: Contestant]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(user.avatarAssetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                    .accessibilityHidden(true)

                Text(user.displayName)
                    .font(.title3)
                    .fontWeight(.semibold)
            }

            PickSection(
                title: "Mergers",
                contestants: contestants(for: seasonPicks?.mergePicks ?? [], limit: 3)
            )

            PickSection(
                title: "Immunity",
                contestants: contestants(for: weeklyPicks?.immunity ?? [], limit: 3)
            )

            PickSection(
                title: "Voted Out",
                contestants: contestants(for: weeklyPicks?.votedOut ?? [], limit: 3)
            )

            PickSection(
                title: "Remain",
                contestants: contestants(
                    for: weeklyPicks?.remain ?? [],
                    limit: 3,
                    excluding: weeklyPicks?.votedOut ?? []
                )
            )
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func contestants(
        for ids: Set<String>,
        limit: Int? = nil,
        excluding excludedIds: Set<String> = []
    ) -> [Contestant] {
        let filteredIds = ids.subtracting(excludedIds)
        let picks = filteredIds.compactMap { contestantsById[$0] }
            .sorted { $0.name < $1.name }
        if let limit {
            return Array(picks.prefix(limit))
        }
        return picks
    }
}

private struct PickSection: View {
    let title: String
    let contestants: [Contestant]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            if contestants.isEmpty {
                Text("No picks yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 12, alignment: .top)], spacing: 12) {
                    ForEach(contestants) { contestant in
                        VStack(spacing: 8) {
                            Image(contestant.id)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(Circle())
                                .accessibilityLabel(contestant.name)

                            Text(contestant.name)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

private struct WeekOption: Identifiable {
    let id: Int
    let title: String
}

#Preview {
    AllPicksView()
        .environmentObject(AppState())
}
