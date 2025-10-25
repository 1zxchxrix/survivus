import SwiftUI

struct ScoreDetailsView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        let model = ScoreDetailsModel(app: app)

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if model.users.isEmpty {
                    Text("No players available yet.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                } else if model.weeks.isEmpty {
                    Text("No scored weeks yet.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.weeks) { week in
                        weekSection(for: week, in: model)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .background(Color(.systemBackground))
        .navigationTitle("Score Details")
    }

    @ViewBuilder
    private func weekSection(for week: ScoreDetailsModel.Week, in model: ScoreDetailsModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(week.title)
                .font(.title3.weight(.semibold))

            ScrollView(.horizontal, showsIndicators: false) {
                let labelWidth: CGFloat = 220
                let userColumnWidth: CGFloat = 140

                VStack(spacing: 0) {
                    headerRow(
                        labelWidth: labelWidth,
                        userColumnWidth: userColumnWidth,
                        users: model.users
                    )

                    Divider()

                    ForEach(Array(week.categories.enumerated()), id: \.element.id) { index, category in
                        HStack(alignment: .top, spacing: 12) {
                            Text(category.title)
                                .font(.subheadline)
                                .frame(width: labelWidth, alignment: .leading)
                                .multilineTextAlignment(.leading)

                            ForEach(model.users) { user in
                                Text(
                                    picksText(
                                        for: category,
                                        user: user,
                                        week: week,
                                        contestantsById: model.contestantsById
                                    )
                                )
                                .font(.subheadline)
                                .frame(width: userColumnWidth, alignment: .leading)
                                .multilineTextAlignment(.leading)
                            }
                        }
                        .padding(.vertical, 8)
                        .background(index.isMultiple(of: 2) ? Color(.tertiarySystemGroupedBackground) : Color.clear)
                    }

                    Divider()

                    summaryRow(
                        title: "Weekly Total",
                        keyPath: \.weekly,
                        week: week,
                        labelWidth: labelWidth,
                        userColumnWidth: userColumnWidth,
                        users: model.users,
                        emphasize: true
                    )

                    summaryRow(
                        title: "Previous Week Total",
                        keyPath: \.previous,
                        week: week,
                        labelWidth: labelWidth,
                        userColumnWidth: userColumnWidth,
                        users: model.users
                    )

                    summaryRow(
                        title: "Current Total",
                        keyPath: \.current,
                        week: week,
                        labelWidth: labelWidth,
                        userColumnWidth: userColumnWidth,
                        users: model.users,
                        emphasize: true
                    )
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
            }

            if !week.votedOutNames.isEmpty {
                Text("Voted out: \(week.votedOutNames.joined(separator: ", "))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func headerRow(
        labelWidth: CGFloat,
        userColumnWidth: CGFloat,
        users: [UserProfile]
    ) -> some View {
        HStack(alignment: .bottom, spacing: 12) {
            Text("Category")
                .font(.footnote.weight(.semibold))
                .frame(width: labelWidth, alignment: .leading)

            ForEach(users) { user in
                Text(user.displayName)
                    .font(.footnote.weight(.semibold))
                    .frame(width: userColumnWidth, alignment: .leading)
            }
        }
        .foregroundStyle(.secondary)
    }

    private func summaryRow(
        title: String,
        keyPath: KeyPath<ScoreDetailsModel.Week.SummaryValues, Int>,
        week: ScoreDetailsModel.Week,
        labelWidth: CGFloat,
        userColumnWidth: CGFloat,
        users: [UserProfile],
        emphasize: Bool = false
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.body)
                .fontWeight(emphasize ? .semibold : .regular)
                .frame(width: labelWidth, alignment: .leading)

            ForEach(users) { user in
                let value = week.summaries[user.id]?[keyPath: keyPath] ?? 0
                Text("\(value)")
                    .font(.body)
                    .fontWeight(emphasize ? .semibold : .regular)
                    .monospacedDigit()
                    .frame(width: userColumnWidth, alignment: .leading)
            }
        }
        .padding(.vertical, 8)
    }

    private func picksText(
        for category: ScoreDetailsModel.Week.Category,
        user: UserProfile,
        week: ScoreDetailsModel.Week,
        contestantsById: [String: Contestant]
    ) -> String {
        guard let picks = week.picksByUser[user.id] else { return "—" }

        switch category.kind {
        case .remain:
            return formattedNames(for: picks.remain, contestantsById: contestantsById)
        case .votedOut:
            return formattedNames(for: picks.votedOut, contestantsById: contestantsById)
        case .immunity:
            return formattedNames(for: picks.immunity, contestantsById: contestantsById)
        case let .custom(id):
            return formattedNames(for: picks.selections(for: id), contestantsById: contestantsById)
        }
    }

    private func formattedNames(
        for ids: Set<String>,
        contestantsById: [String: Contestant]
    ) -> String {
        guard !ids.isEmpty else { return "—" }

        let names = ids
            .map { contestantsById[$0]?.name ?? $0 }
            .sorted()

        return names.joined(separator: "\n")
    }
}

private struct ScoreDetailsModel {
    struct Week: Identifiable {
        struct Category: Identifiable {
            let kind: CategoryKind
            let name: String
            let pointsText: String

            var id: String { kind.id }
            var title: String { "\(name) (\(pointsText))" }
        }

        struct SummaryValues {
            let weekly: Int
            let previous: Int
            let current: Int
        }

        let id: Int
        let title: String
        let categories: [Category]
        let picksByUser: [String: WeeklyPicks]
        let summaries: [String: SummaryValues]
        let votedOutNames: [String]
    }

    enum CategoryKind: Hashable {
        case remain
        case votedOut
        case immunity
        case custom(UUID)

        var id: String {
            switch self {
            case .remain:
                return "remain"
            case .votedOut:
                return "votedOut"
            case .immunity:
                return "immunity"
            case let .custom(id):
                return "custom-\(id.uuidString)"
            }
        }
    }

    let users: [UserProfile]
    let contestantsById: [String: Contestant]
    let weeks: [Week]

    @MainActor
    init(app: AppState) {
        let store = app.store
        let scoring = app.scoring
        let results = store.results.filter(\.hasRecordedResults)
        let categoriesById: [UUID: PickPhase.Category] = Dictionary(uniqueKeysWithValues: app.phases.flatMap { phase in
            phase.categories.map { ($0.id, $0) }
        })
        let contestantsById = Dictionary(uniqueKeysWithValues: store.config.contestants.map { ($0.id, $0) })
        let breakdowns = ScoreDetailsModel.makeBreakdowns(
            users: store.users,
            store: store,
            scoring: scoring,
            categoriesById: categoriesById,
            results: results
        )
        let usersById = Dictionary(uniqueKeysWithValues: store.users.map { ($0.id, $0) })
        var orderedUsers: [UserProfile] = breakdowns.compactMap { usersById[$0.userId] }
        if orderedUsers.count < store.users.count {
            let remaining = store.users.filter { user in
                !orderedUsers.contains(where: { $0.id == user.id })
            }
            orderedUsers.append(contentsOf: remaining)
        }

        self.users = orderedUsers
        self.contestantsById = contestantsById
        self.weeks = ScoreDetailsModel.makeWeeks(
            results: results,
            orderedUsers: orderedUsers,
            store: store,
            scoring: scoring,
            phases: app.phases,
            categoriesById: categoriesById,
            contestantsById: contestantsById
        )
    }

    private static func makeBreakdowns(
        users: [UserProfile],
        store: MemoryStore,
        scoring: ScoringEngine,
        categoriesById: [UUID: PickPhase.Category],
        results: [EpisodeResult]
    ) -> [UserScoreBreakdown] {
        let episodesById = Dictionary(uniqueKeysWithValues: store.config.episodes.map { ($0.id, $0) })
        let scoredEpisodeIds = results.map(\.id).sorted()
        let lastEpisodeWithResult = scoredEpisodeIds.last ?? 0

        return users.map { user in
            var votedOutPoints = 0
            var remainPoints = 0
            var immunityPoints = 0
            var weeksParticipated = 0
            var categoryPoints: [String: Int] = [:]

            for episodeId in scoredEpisodeIds {
                let episode = episodesById[episodeId] ?? Episode(id: episodeId)
                if let picks = store.weeklyPicks[user.id]?[episodeId] {
                    weeksParticipated += 1
                    let score = scoring.score(weekly: picks, episode: episode, categoriesById: categoriesById)
                    votedOutPoints += score.votedOut
                    remainPoints += score.remain
                    immunityPoints += score.immunity
                    for (columnId, points) in score.categoryPointsByColumnId {
                        categoryPoints[columnId, default: 0] += points
                    }
                }
            }

            let season = store.seasonPicks[user.id] ?? SeasonPicks(userId: user.id)
            let mergePoints = scoring.mergeTrackPoints(for: user.id, upTo: lastEpisodeWithResult, seasonPicks: season)
            let finalThreePoints = scoring.finalThreeTrackPoints(for: user.id, upTo: lastEpisodeWithResult, seasonPicks: season)
            let finalResult = scoring.resultsByEpisode[lastEpisodeWithResult]
            let winnerPoints = scoring.winnerPoints(seasonPicks: season, finalResult: finalResult)

            return UserScoreBreakdown(
                userId: user.id,
                weeksParticipated: weeksParticipated,
                votedOutPoints: votedOutPoints,
                remainPoints: remainPoints,
                immunityPoints: immunityPoints,
                mergeTrackPoints: mergePoints,
                finalThreeTrackPoints: finalThreePoints,
                winnerPoints: winnerPoints,
                categoryPointsByColumnId: categoryPoints
            )
        }
        .sorted { $0.total > $1.total }
    }

    private static func makeWeeks(
        results: [EpisodeResult],
        orderedUsers: [UserProfile],
        store: MemoryStore,
        scoring: ScoringEngine,
        phases: [PickPhase],
        categoriesById: [UUID: PickPhase.Category],
        contestantsById: [String: Contestant]
    ) -> [Week] {
        guard !orderedUsers.isEmpty else { return [] }

        let episodesById = Dictionary(uniqueKeysWithValues: store.config.episodes.map { ($0.id, $0) })
        let sortedResults = results.sorted { $0.id < $1.id }

        var weeks: [Week] = []
        var cumulativeTotals: [String: Int] = [:]
        var previousMergeTotals: [String: Int] = [:]
        var previousFinalTotals: [String: Int] = [:]
        var previousWinnerTotals: [String: Int] = [:]

        for result in sortedResults {
            let episode = episodesById[result.id] ?? Episode(id: result.id)
            var picksByUser: [String: WeeklyPicks] = [:]

            for user in orderedUsers {
                if let picks = store.weeklyPicks[user.id]?[episode.id] {
                    picksByUser[user.id] = picks
                }
            }

            let categories = makeCategories(
                for: episode,
                result: result,
                picksByUser: picksByUser,
                phases: phases,
                categoriesById: categoriesById,
                scoring: scoring
            )

            var summaries: [String: Week.SummaryValues] = [:]

            for user in orderedUsers {
                let userId = user.id
                let season = store.seasonPicks[userId] ?? SeasonPicks(userId: userId)
                let breakdown: WeeklyScoreBreakdown

                if let picks = picksByUser[userId] {
                    breakdown = scoring.score(weekly: picks, episode: episode, categoriesById: categoriesById)
                } else {
                    breakdown = WeeklyScoreBreakdown(
                        votedOut: 0,
                        remain: 0,
                        immunity: 0,
                        categoryPointsByColumnId: [:]
                    )
                }

                let categoryPointsTotal = breakdown.categoryPointsByColumnId.values.reduce(0, +)
                let baseWeeklyPoints = breakdown.votedOut + breakdown.remain + breakdown.immunity + categoryPointsTotal

                let mergeToDate = scoring.mergeTrackPoints(for: userId, upTo: episode.id, seasonPicks: season)
                let mergePrev = previousMergeTotals[userId] ?? 0
                let mergeWeekly = mergeToDate - mergePrev
                previousMergeTotals[userId] = mergeToDate

                let finalToDate = scoring.finalThreeTrackPoints(for: userId, upTo: episode.id, seasonPicks: season)
                let finalPrev = previousFinalTotals[userId] ?? 0
                let finalWeekly = finalToDate - finalPrev
                previousFinalTotals[userId] = finalToDate

                let winnerToDate = scoring.winnerPoints(seasonPicks: season, finalResult: scoring.resultsByEpisode[episode.id])
                let winnerPrev = previousWinnerTotals[userId] ?? 0
                let winnerWeekly = max(0, winnerToDate - winnerPrev)
                previousWinnerTotals[userId] = winnerToDate

                let weeklyTotal = baseWeeklyPoints + mergeWeekly + finalWeekly + winnerWeekly
                let previousTotal = cumulativeTotals[userId] ?? 0
                let currentTotal = previousTotal + weeklyTotal
                cumulativeTotals[userId] = currentTotal

                summaries[userId] = Week.SummaryValues(
                    weekly: weeklyTotal,
                    previous: previousTotal,
                    current: currentTotal
                )
            }

            let votedOutNames = result.votedOut.map { contestantsById[$0]?.name ?? $0 }

            weeks.append(
                Week(
                    id: episode.id,
                    title: episode.title,
                    categories: categories,
                    picksByUser: picksByUser,
                    summaries: summaries,
                    votedOutNames: votedOutNames
                )
            )
        }

        return weeks
    }

    private static func makeCategories(
        for episode: Episode,
        result: EpisodeResult,
        picksByUser: [String: WeeklyPicks],
        phases: [PickPhase],
        categoriesById: [UUID: PickPhase.Category],
        scoring: ScoringEngine
    ) -> [Week.Category] {
        var categories: [Week.Category] = []
        let phase = scoring.phase(for: episode)

        categories.append(
            Week.Category(
                kind: .remain,
                name: "Who Will Remain",
                pointsText: "1"
            )
        )

        categories.append(
            Week.Category(
                kind: .votedOut,
                name: "Who Will Be Voted Out",
                pointsText: "3"
            )
        )

        let immunityPoints = phase == .preMerge ? 1 : 3
        categories.append(
            Week.Category(
                kind: .immunity,
                name: "Who Will Have Immunity",
                pointsText: "\(immunityPoints)"
            )
        )

        var customCategoryIds = Set(result.categoryWinners.keys)
        for picks in picksByUser.values {
            for categoryId in picks.categorySelections.keys {
                customCategoryIds.insert(categoryId)
            }
        }

        guard !customCategoryIds.isEmpty else { return categories }

        var remaining = customCategoryIds

        for phase in phases {
            for category in phase.categories {
                guard remaining.contains(category.id) else { continue }

                if category.matchesRemainCategory || category.matchesVotedOutCategory || category.matchesImmunityCategory {
                    remaining.remove(category.id)
                    continue
                }

                let name = displayName(for: category)
                let pointsText = category.pointsPerCorrectPick.map(String.init) ?? "—"

                categories.append(
                    Week.Category(
                        kind: .custom(category.id),
                        name: name,
                        pointsText: pointsText
                    )
                )
                remaining.remove(category.id)
            }
        }

        for id in remaining {
            if let category = categoriesById[id] {
                if category.matchesRemainCategory || category.matchesVotedOutCategory || category.matchesImmunityCategory {
                    continue
                }

                let name = displayName(for: category)
                let pointsText = category.pointsPerCorrectPick.map(String.init) ?? "—"

                categories.append(
                    Week.Category(
                        kind: .custom(id),
                        name: name,
                        pointsText: pointsText
                    )
                )
            } else {
                categories.append(
                    Week.Category(
                        kind: .custom(id),
                        name: "Category",
                        pointsText: "—"
                    )
                )
            }
        }

        return categories
    }

    private static func displayName(for category: PickPhase.Category) -> String {
        let trimmed = category.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }

        let columnId = category.columnId.trimmingCharacters(in: .whitespacesAndNewlines)
        return columnId.isEmpty ? "Category" : columnId
    }
}

#Preview {
    NavigationStack {
        ScoreDetailsView()
            .environmentObject(AppState.preview)
    }
}
