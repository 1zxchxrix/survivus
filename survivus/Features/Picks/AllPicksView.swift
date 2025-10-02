import SwiftUI

struct AllPicksView: View {
    @EnvironmentObject var app: AppState
    @State private var selectedWeekId: Int = 13

    private var weekOptions: [WeekOption] {
        var options = app.store.config.episodes.map { WeekOption(id: $0.id, title: $0.title) }
        if let index = options.firstIndex(where: { $0.id == 13 }) {
            options[index] = WeekOption(id: 13, title: "Week 13 (Current)")
        } else {
            options.append(WeekOption(id: 13, title: "Week 13 (Current)"))
        }
        return options.sorted { $0.id < $1.id }
    }

    private var contestantsById: [String: Contestant] {
        Dictionary(uniqueKeysWithValues: app.store.config.contestants.map { ($0.id, $0) })
    }

    private var eliminatedContestantsForSelectedWeek: Set<String> {
        eliminatedContestantIds(upTo: selectedWeekId)
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
                            contestantsById: contestantsById,
                            eliminatedContestants: eliminatedContestantsForSelectedWeek
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("All Picks")
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
    let eliminatedContestants: Set<String>

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
                contestants: contestants(for: seasonPicks?.mergePicks ?? []),
                eliminatedContestantIds: eliminatedContestants
            )

            PickSection(
                title: "Immunity",
                contestants: contestants(for: weeklyPicks?.immunity ?? [])
            )

            PickSection(
                title: "Voted Out",
                contestants: contestants(for: weeklyPicks?.votedOut ?? [])
            )

            PickSection(
                title: "Remain",
                contestants: contestants(for: weeklyPicks?.remain ?? [])
            )
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func contestants(for ids: Set<String>) -> [Contestant] {
        ids.compactMap { contestantsById[$0] }
            .sorted { $0.name < $1.name }
    }
}

private struct PickSection: View {
    let title: String
    let contestants: [Contestant]
    let eliminatedContestantIds: Set<String> = []

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
                        let isEliminated = eliminatedContestantIds.contains(contestant.id)
                        VStack(spacing: 8) {
                            Image(contestant.id)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(Circle())
                                .grayscale(isEliminated ? 1 : 0)
                                .opacity(isEliminated ? 0.45 : 1)
                                .accessibilityLabel(contestant.name)

                            Text(contestant.name)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(isEliminated ? .tertiary : .secondary)
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

private extension AllPicksView {
    func eliminatedContestantIds(upTo weekId: Int) -> Set<String> {
        let relevantResults = app.store.results.filter { $0.id <= weekId }
        return Set(relevantResults.flatMap { $0.votedOut })
    }
}

#Preview {
    AllPicksView()
        .environmentObject(AppState())
}
