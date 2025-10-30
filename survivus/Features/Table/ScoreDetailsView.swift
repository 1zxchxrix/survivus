import Foundation
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
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(week.title)
                    .font(.title3.weight(.semibold))

                Text("– \(week.phaseName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                let labelWidth: CGFloat = 160
                let userColumnWidth: CGFloat = 140

                VStack(spacing: 0) {
                    headerRow(
                        labelWidth: labelWidth,
                        userColumnWidth: userColumnWidth,
                        users: model.users
                    )

                    ForEach(Array(week.categories.enumerated()), id: \.element.id) { index, category in
                        let rowBackground = index.isMultiple(of: 2) ? Color(.tertiarySystemGroupedBackground) : Color.clear

                        HStack(alignment: .top, spacing: 0) {
                            tableCell(
                                width: labelWidth,
                                showTrailingDivider: !model.users.isEmpty
                            ) {
                                let label = category.pointsText.isEmpty
                                    ? category.name
                                    : "\(category.name) (\(category.pointsText))"

                                Text(label)
                                    .font(.subheadline)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(1)
                            }

                            ForEach(Array(model.users.enumerated()), id: \.element.id) { userIndex, user in
                                tableCell(
                                    width: userColumnWidth,
                                    showTrailingDivider: userIndex != model.users.count - 1
                                ) {
                                    Text(
                                        picksText(
                                            for: category,
                                            user: user,
                                            week: week,
                                            contestantsById: model.contestantsById
                                        )
                                    )
                                    .font(.subheadline)
                                    .multilineTextAlignment(.leading)
                                }
                            }
                        }
                        .background(rowBackground)
                        .overlay(alignment: .bottom) {
                            Color(.separator)
                                .frame(height: 1)
                        }
                    }

                    summaryRow(
                        title: "Weekly Total",
                        keyPath: \.weekly,
                        week: week,
                        labelWidth: labelWidth,
                        userColumnWidth: userColumnWidth,
                        users: model.users,
                        emphasize: true,
                        showBottomDivider: true
                    )

                    summaryRow(
                        title: "Previous Week Total",
                        keyPath: \.previous,
                        week: week,
                        labelWidth: labelWidth,
                        userColumnWidth: userColumnWidth,
                        users: model.users,
                        showBottomDivider: true
                    )

                    summaryRow(
                        title: "Current Total",
                        keyPath: \.current,
                        week: week,
                        labelWidth: labelWidth,
                        userColumnWidth: userColumnWidth,
                        users: model.users,
                        emphasize: true,
                        showBottomDivider: false
                    )
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(.separator), lineWidth: 1)
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
        HStack(spacing: 0) {
            tableCell(
                width: labelWidth,
                showTrailingDivider: !users.isEmpty,
                verticalPadding: 10
            ) {
                Text("Category")
                    .font(.footnote.weight(.semibold))
                    .multilineTextAlignment(.leading)
            }

            ForEach(Array(users.enumerated()), id: \.element.id) { index, user in
                tableCell(
                    width: userColumnWidth,
                    showTrailingDivider: index != users.count - 1,
                    verticalPadding: 10
                ) {
                    Text(user.displayName)
                        .font(.footnote.weight(.semibold))
                        .multilineTextAlignment(.leading)
                        .lineLimit(1)
                }
            }
        }
        .foregroundStyle(.secondary)
        .background(Color(.secondarySystemBackground))
        .overlay(alignment: .bottom) {
            Color(.separator)
                .frame(height: 1)
        }
    }

    private func summaryRow(
        title: String,
        keyPath: KeyPath<ScoreDetailsModel.Week.SummaryValues, Int>,
        week: ScoreDetailsModel.Week,
        labelWidth: CGFloat,
        userColumnWidth: CGFloat,
        users: [UserProfile],
        emphasize: Bool = false,
        showBottomDivider: Bool
    ) -> some View {
        HStack(alignment: .center, spacing: 0) {
            tableCell(
                width: labelWidth,
                showTrailingDivider: !users.isEmpty
            ) {
                Text(title)
                    .font(.body)
                    .fontWeight(emphasize ? .semibold : .regular)
            }

            ForEach(Array(users.enumerated()), id: \.element.id) { index, user in
                let value = week.summaries[user.id]?[keyPath: keyPath] ?? 0
                tableCell(
                    width: userColumnWidth,
                    showTrailingDivider: index != users.count - 1
                ) {
                    Text("\(value)")
                        .font(.body)
                        .fontWeight(emphasize ? .semibold : .regular)
                        .monospacedDigit()
                }
            }
        }
        .overlay(alignment: .bottom) {
            if showBottomDivider {
                Color(.separator)
                    .frame(height: 1)
            }
        }
    }

    @ViewBuilder
    private func tableCell<Content: View>(
        width: CGFloat,
        alignment: Alignment = .leading,
        showTrailingDivider: Bool,
        verticalPadding: CGFloat = 8,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(width: width, alignment: alignment)
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, 12)
            .overlay(alignment: .trailing) {
                if showTrailingDivider {
                    Color(.separator)
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                }
            }
    }

    private func picksText(
        for category: ScoreDetailsModel.Week.Category,
        user: UserProfile,
        week: ScoreDetailsModel.Week,
        contestantsById: [String: Contestant]
    ) -> String {
        let weeklyPicks = week.picksByUser[user.id]
        let pointsByPick = category.pointsByPick(for: user.id)

        if let categoryId = category.categoryId, let picks = weeklyPicks {
            return formattedNames(
                for: picks.selections(for: categoryId),
                contestantsById: contestantsById,
                pointsById: pointsByPick
            )
        }

        if let correct = category.correctPicksByUser[user.id], !correct.isEmpty {
            return formattedNames(
                for: correct,
                contestantsById: contestantsById,
                pointsById: pointsByPick
            )
        }

        return "—"
    }

    private func formattedNames(
        for ids: Set<String>,
        contestantsById: [String: Contestant],
        pointsById: [String: Int] = [:]
    ) -> String {
        guard !ids.isEmpty else { return "—" }

        let entries: [(display: String, sortKey: String)] = ids.map { id in
            let name = contestantsById[id]?.name ?? id
            let shortName = shortenedDisplayName(for: name)
            if let points = pointsById[id], points > 0 {
                return ("\(shortName) (\(points))", name)
            } else {
                return (shortName, name)
            }
        }

        let sorted = entries.sorted { lhs, rhs in
            lhs.sortKey.localizedCaseInsensitiveCompare(rhs.sortKey) == .orderedAscending
        }

        return sorted.map(\.display).joined(separator: "\n")
    }

}

    private struct ScoreDetailsModel {
        struct Week: Identifiable {
            struct Category: Identifiable {
                let categoryId: UUID?
                let name: String
                let pointsText: String
                let correctPicksByUser: [String: Set<String>]
                let pointsPerCorrectPick: Int?
                let wagerPoints: Int?

                var id: String { categoryId?.uuidString ?? name }

                func pointsByPick(for userId: String) -> [String: Int] {
                    guard let perPick = pointsPerCorrectPick, perPick > 0 else { return [:] }
                    guard let picks = correctPicksByUser[userId], !picks.isEmpty else { return [:] }

                    return Dictionary(uniqueKeysWithValues: picks.map { ($0, perPick) })
                }
            }

        struct SummaryValues {
            let weekly: Int
            let previous: Int
            let current: Int
        }

        let id: Int
        let title: String
        let phaseName: String
        let categories: [Category]
        let picksByUser: [String: WeeklyPicks]
        let summaries: [String: SummaryValues]
        let votedOutNames: [String]
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
            phases: app.phases,
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
        phases: [PickPhase],
        categoriesById: [UUID: PickPhase.Category],
        results: [EpisodeResult]
    ) -> [UserScoreBreakdown] {
        let episodesById = Dictionary(uniqueKeysWithValues: store.config.episodes.map { ($0.id, $0) })
        let scoredEpisodeIds = results.map(\.id).sorted()
        let lastEpisodeWithResult = scoredEpisodeIds.last ?? 0
        let phasesById = Dictionary(uniqueKeysWithValues: phases.map { ($0.id, $0) })
        let phaseByEpisodeId: [Int: PickPhase] = Dictionary(uniqueKeysWithValues: results.compactMap { result in
            guard let phaseId = result.phaseId, let phase = phasesById[phaseId] else { return nil }
            return (result.id, phase)
        })

        return users.map { user in
            var weeksParticipated = 0
            var categoryPoints: [String: Int] = [:]

            for episodeId in scoredEpisodeIds {
                let episode = episodesById[episodeId] ?? Episode(id: episodeId)
                if let picks = store.weeklyPicks[user.id]?[episodeId] {
                    weeksParticipated += 1
                    let configuredPhase = phaseByEpisodeId[episodeId]
                    let score = scoring.score(weekly: picks, episode: episode, phaseOverride: configuredPhase, categoriesById: categoriesById)
                    for (columnId, points) in score.categoryPointsByColumnId {
                        categoryPoints[columnId, default: 0] += points
                    }
                }
            }

            return UserScoreBreakdown(
                userId: user.id,
                weeksParticipated: weeksParticipated,
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
        let phasesById = Dictionary(uniqueKeysWithValues: phases.map { ($0.id, $0) })
        let phaseByEpisodeId: [Int: PickPhase] = Dictionary(uniqueKeysWithValues: sortedResults.compactMap { result in
            guard let phaseId = result.phaseId, let phase = phasesById[phaseId] else { return nil }
            return (result.id, phase)
        })

        var weeks: [Week] = []
        var cumulativeTotals: [String: Int] = [:]
        let phaseInfoByCategoryId: [UUID: (name: String, order: Int)] = {
            var mapping: [UUID: (name: String, order: Int)] = [:]
            for (index, phase) in phases.enumerated() {
                for category in phase.categories {
                    mapping[category.id] = (phase.name, index)
                }
            }
            return mapping
        }()
        var eliminatedContestantIds: Set<String> = []

        for result in sortedResults {
            let episode = episodesById[result.id] ?? Episode(id: result.id)
            var picksByUser: [String: WeeklyPicks] = [:]

            for user in orderedUsers {
                if let picks = store.weeklyPicks[user.id]?[episode.id] {
                    picksByUser[user.id] = picks
                }
            }

            let defaultPhase = scoring.phase(for: episode)
            let configuredPhase = phaseByEpisodeId[result.id]
            let priorEliminations = eliminatedContestantIds
            let currentVotedOut = Set(result.votedOut)
            let winnersByCategory = result.categoryWinners.mapValues { Set($0) }

            var orderedCategories: [PickPhase.Category] = []
            var seenCategoryIds: Set<UUID> = []

            if let configuredPhase {
                for category in configuredPhase.categories {
                    orderedCategories.append(category)
                    seenCategoryIds.insert(category.id)
                }
            }

            for categoryId in winnersByCategory.keys where !seenCategoryIds.contains(categoryId) {
                if let category = categoriesById[categoryId] {
                    orderedCategories.append(category)
                    seenCategoryIds.insert(categoryId)
                }
            }

            for picks in picksByUser.values {
                for categoryId in picks.categorySelections.keys where !seenCategoryIds.contains(categoryId) {
                    if let category = categoriesById[categoryId] {
                        orderedCategories.append(category)
                        seenCategoryIds.insert(categoryId)
                    }
                }
            }

            var categories: [Week.Category] = []

            for category in orderedCategories {
                let correctByUser = correctSelections(
                    for: category,
                    picksByUser: picksByUser,
                    winnersByCategory: winnersByCategory,
                    priorEliminations: priorEliminations,
                    currentVotedOut: currentVotedOut
                )
                let points = pointsDescription(for: category)
                categories.append(
                    Week.Category(
                        categoryId: category.id,
                        name: displayName(for: category),
                        pointsText: points.text,
                        correctPicksByUser: correctByUser,
                        pointsPerCorrectPick: points.perPick,
                        wagerPoints: points.wager
                    )
                )
            }

            var summaries: [String: Week.SummaryValues] = [:]

            for user in orderedUsers {
                let userId = user.id
                let breakdown: WeeklyScoreBreakdown

                if let picks = picksByUser[userId] {
                    breakdown = scoring.score(weekly: picks, episode: episode, phaseOverride: configuredPhase, categoriesById: categoriesById)
                } else {
                    breakdown = WeeklyScoreBreakdown(categoryPointsByColumnId: [:])
                }

                let weeklyTotal = breakdown.categoryPointsByColumnId.values.reduce(0, +)
                let previousTotal = cumulativeTotals[userId] ?? 0
                let currentTotal = previousTotal + weeklyTotal
                cumulativeTotals[userId] = currentTotal

                summaries[userId] = Week.SummaryValues(
                    weekly: weeklyTotal,
                    previous: previousTotal,
                    current: currentTotal
                )
            }

            let phaseDisplayName = phaseName(
                for: categories,
                defaultPhase: defaultPhase,
                configuredPhase: configuredPhase,
                phases: phases,
                phaseInfoByCategoryId: phaseInfoByCategoryId
            )

            let votedOutNames = result.votedOut.map { id -> String in
                let fullName = contestantsById[id]?.name ?? id
                return shortenedDisplayName(for: fullName)
            }

            weeks.append(
                Week(
                    id: episode.id,
                    title: episode.title,
                    phaseName: phaseDisplayName,
                    categories: categories,
                    picksByUser: picksByUser,
                    summaries: summaries,
                    votedOutNames: votedOutNames
                )
            )

            eliminatedContestantIds.formUnion(currentVotedOut)
        }

        return weeks.sorted(by: { $0.id > $1.id })
    }

    private static func phaseName(
        for categories: [Week.Category],
        defaultPhase: Phase,
        configuredPhase: PickPhase?,
        phases: [PickPhase],
        phaseInfoByCategoryId: [UUID: (name: String, order: Int)]
    ) -> String {
        if let configuredPhase {
            return configuredPhase.name
        }

        let candidates: [(order: Int, name: String)] = categories.compactMap { category in
            guard let categoryId = category.categoryId, let info = phaseInfoByCategoryId[categoryId] else {
                return nil
            }
            return (info.order, info.name)
        }

        if let selected = candidates.sorted(by: { $0.order < $1.order }).last {
            return selected.name
        }

        return fallbackPhaseName(for: defaultPhase, phases: phases)
    }

    private static func fallbackPhaseName(
        for defaultPhase: Phase,
        phases: [PickPhase]
    ) -> String {
        switch defaultPhase {
        case .preMerge:
            if let match = phases.first(where: { phase in
                let name = phase.name
                return name.range(of: "pre", options: .caseInsensitive) != nil &&
                    name.range(of: "merge", options: .caseInsensitive) != nil
            }) {
                return match.name
            }
            return "Pre-merge"
        case .postMerge:
            if let match = phases.first(where: { phase in
                let name = phase.name
                return name.range(of: "post", options: .caseInsensitive) != nil &&
                    name.range(of: "merge", options: .caseInsensitive) != nil
            }) {
                return match.name
            }
            return "Post-merge"
        }
    }

    private static func correctSelections(
        for category: PickPhase.Category,
        picksByUser: [String: WeeklyPicks],
        winnersByCategory: [UUID: Set<String>],
        priorEliminations: Set<String>,
        currentVotedOut: Set<String>
    ) -> [String: Set<String>] {
        var result: [String: Set<String>] = [:]

        for (userId, picks) in picksByUser {
            let selections = picks.selections(for: category.id)
            guard !selections.isEmpty else { continue }

            let hits: Set<String>
            if category.autoScoresRemainingContestants {
                hits = selections
                    .subtracting(priorEliminations)
                    .subtracting(currentVotedOut)
            } else {
                let winners = winnersByCategory[category.id] ?? []
                hits = selections.intersection(winners)
            }

            if !hits.isEmpty {
                result[userId] = hits
            }
        }

        return result
    }

    private static func pointsDescription(for category: PickPhase.Category) -> (text: String, perPick: Int?, wager: Int?) {
        if let wager = category.wagerPoints, wager > 0 {
            return ("±\(wager)", nil, wager)
        }

        if let configured = category.pointsPerCorrectPick, configured > 0 {
            return ("\(configured)", configured, nil)
        }

        return ("—", nil, nil)
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

private func shortenedDisplayName(for fullName: String) -> String {
    let components = fullName
        .split(whereSeparator: { $0.isWhitespace })
        .map(String.init)

    guard let first = components.first else {
        return fullName
    }

    guard let last = components.last, last != first, let initial = last.first else {
        return first
    }

    return "\(first) \(String(initial))."
}

#Preview {
    NavigationStack {
        ScoreDetailsView()
            .environmentObject(AppState.preview)
    }
}
