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

        switch category.kind {
        case .merge:
            let selections = week.mergePicksByUser[user.id] ?? []
            return formattedNames(
                for: selections,
                contestantsById: contestantsById,
                pointsById: pointsByPick
            )
        case .remain:
            guard let picks = weeklyPicks else { return "—" }
            return formattedNames(
                for: picks.remain,
                contestantsById: contestantsById,
                pointsById: pointsByPick
            )
        case .votedOut:
            guard let picks = weeklyPicks else { return "—" }
            return formattedNames(
                for: picks.votedOut,
                contestantsById: contestantsById,
                pointsById: pointsByPick
            )
        case .immunity:
            guard let picks = weeklyPicks else { return "—" }
            return formattedNames(
                for: picks.immunity,
                contestantsById: contestantsById,
                pointsById: pointsByPick
            )
        case let .custom(id):
            guard let picks = weeklyPicks else { return "—" }
            return formattedNames(
                for: picks.selections(for: id),
                contestantsById: contestantsById,
                pointsById: pointsByPick
            )
        }
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
            let kind: CategoryKind
            let name: String
            let pointsText: String
            let correctPicksByUser: [String: Set<String>]
            let pointsPerCorrectPick: Int?

            var id: String { kind.id }

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
        let mergePicksByUser: [String: Set<String>]
        let summaries: [String: SummaryValues]
        let votedOutNames: [String]
    }

    enum CategoryKind: Hashable {
        case remain
        case votedOut
        case immunity
        case merge
        case custom(UUID)

        var id: String {
            switch self {
            case .remain:
                return "remain"
            case .votedOut:
                return "votedOut"
            case .immunity:
                return "immunity"
            case .merge:
                return "merge"
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
        let phaseInfoByCategoryId: [UUID: (name: String, order: Int)] = {
            var mapping: [UUID: (name: String, order: Int)] = [:]
            for (index, phase) in phases.enumerated() {
                for category in phase.categories {
                    mapping[category.id] = (phase.name, index)
                }
            }
            return mapping
        }()
        let seasonsByUser: [String: SeasonPicks] = Dictionary(uniqueKeysWithValues: orderedUsers.map { user in
            (user.id, store.seasonPicks[user.id] ?? SeasonPicks(userId: user.id))
        })
        let hasMergePicks = seasonsByUser.values.contains { !$0.mergePicks.isEmpty }
        let mergeSelectionsByUser: [String: Set<String>] = {
            guard hasMergePicks else { return [:] }

            var selections: [String: Set<String>] = [:]
            for (userId, season) in seasonsByUser {
                let picks = season.mergePicks
                if !picks.isEmpty {
                    selections[userId] = picks
                }
            }

            return selections
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

            let phase = scoring.phase(for: episode)
            let immunityPoints = phase == .preMerge ? 1 : 3
            let votedOutSet = Set(result.votedOut)
            let immunityWinnerSet = Set(result.immunityWinners)
            let customWinnerSets = result.categoryWinners.mapValues { Set($0) }
            let eliminatedThroughCurrentEpisode = eliminatedContestantIds.union(votedOutSet)

            var correctRemainByUser: [String: Set<String>] = [:]
            var correctVotedOutByUser: [String: Set<String>] = [:]
            var correctImmunityByUser: [String: Set<String>] = [:]
            var correctCustomByCategory: [UUID: [String: Set<String>]] = [:]

            for (userId, picks) in picksByUser {
                let remainHits = picks.remain.subtracting(eliminatedThroughCurrentEpisode)
                if !remainHits.isEmpty {
                    correctRemainByUser[userId] = remainHits
                }

                let votedOutHits = picks.votedOut.intersection(votedOutSet)
                if !votedOutHits.isEmpty {
                    correctVotedOutByUser[userId] = votedOutHits
                }

                let immunityHits = picks.immunity.intersection(immunityWinnerSet)
                if !immunityHits.isEmpty {
                    correctImmunityByUser[userId] = immunityHits
                }

                for (categoryId, selections) in picks.categorySelections {
                    let winners = customWinnerSets[categoryId] ?? []
                    let hits = selections.intersection(winners)
                    if !hits.isEmpty {
                        var userMap = correctCustomByCategory[categoryId, default: [:]]
                        userMap[userId] = hits
                        correctCustomByCategory[categoryId] = userMap
                    }
                }
            }

            var mergeAliveByUser: [String: Set<String>] = [:]
            if hasMergePicks {
                for (userId, season) in seasonsByUser {
                    let alive = season.mergePicks.subtracting(eliminatedThroughCurrentEpisode)
                    if !alive.isEmpty {
                        mergeAliveByUser[userId] = alive
                    }
                }
            }

            let categories = makeCategories(
                result: result,
                picksByUser: picksByUser,
                phases: phases,
                categoriesById: categoriesById,
                immunityPoints: immunityPoints,
                includeMergeCategory: hasMergePicks,
                mergeAliveByUser: mergeAliveByUser,
                correctRemainByUser: correctRemainByUser,
                correctVotedOutByUser: correctVotedOutByUser,
                correctImmunityByUser: correctImmunityByUser,
                correctCustomByCategory: correctCustomByCategory
            )

            var summaries: [String: Week.SummaryValues] = [:]
            var awardedFinalPoints = false
            var awardedWinnerPoints = false

            for user in orderedUsers {
                let userId = user.id
                let season = seasonsByUser[userId] ?? SeasonPicks(userId: userId)
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
                if finalWeekly > 0 { awardedFinalPoints = true }
                previousFinalTotals[userId] = finalToDate

                let winnerToDate = scoring.winnerPoints(seasonPicks: season, finalResult: scoring.resultsByEpisode[episode.id])
                let winnerPrev = previousWinnerTotals[userId] ?? 0
                let winnerWeekly = max(0, winnerToDate - winnerPrev)
                if winnerWeekly > 0 { awardedWinnerPoints = true }
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

            let phaseDisplayName = phaseName(
                for: categories,
                defaultPhase: phase,
                phases: phases,
                phaseInfoByCategoryId: phaseInfoByCategoryId,
                hasFinalPoints: awardedFinalPoints || awardedWinnerPoints
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
                    mergePicksByUser: mergeSelectionsByUser,
                    summaries: summaries,
                    votedOutNames: votedOutNames
                )
            )

            eliminatedContestantIds = eliminatedThroughCurrentEpisode
        }

        return weeks.sorted(by: { $0.id > $1.id })
    }

    private static func phaseName(
        for categories: [Week.Category],
        defaultPhase: Phase,
        phases: [PickPhase],
        phaseInfoByCategoryId: [UUID: (name: String, order: Int)],
        hasFinalPoints: Bool
    ) -> String {
        let candidates: [(order: Int, name: String)] = categories.compactMap { category in
            if case let .custom(id) = category.kind, let info = phaseInfoByCategoryId[id] {
                return (info.order, info.name)
            }
            return nil
        }

        if let selected = candidates.sorted(by: { $0.order < $1.order }).last {
            return selected.name
        }

        return fallbackPhaseName(for: defaultPhase, phases: phases, hasFinalPoints: hasFinalPoints)
    }

    private static func fallbackPhaseName(
        for defaultPhase: Phase,
        phases: [PickPhase],
        hasFinalPoints: Bool
    ) -> String {
        if hasFinalPoints {
            if let finalsPhase = phases.first(where: { phase in
                phase.name.range(of: "final", options: .caseInsensitive) != nil
            }) {
                return finalsPhase.name
            }
            return "Finale"
        }

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

    private static func makeCategories(
        result: EpisodeResult,
        picksByUser: [String: WeeklyPicks],
        phases: [PickPhase],
        categoriesById: [UUID: PickPhase.Category],
        immunityPoints: Int,
        includeMergeCategory: Bool,
        mergeAliveByUser: [String: Set<String>],
        correctRemainByUser: [String: Set<String>],
        correctVotedOutByUser: [String: Set<String>],
        correctImmunityByUser: [String: Set<String>],
        correctCustomByCategory: [UUID: [String: Set<String>]]
    ) -> [Week.Category] {
        var categories: [Week.Category] = []

        categories.append(
            Week.Category(
                kind: .remain,
                name: "Remain",
                pointsText: "1",
                correctPicksByUser: correctRemainByUser,
                pointsPerCorrectPick: 1
            )
        )

        categories.append(
            Week.Category(
                kind: .votedOut,
                name: "Voted out",
                pointsText: "3",
                correctPicksByUser: correctVotedOutByUser,
                pointsPerCorrectPick: 3
            )
        )

        categories.append(
            Week.Category(
                kind: .immunity,
                name: "Immunity",
                pointsText: "\(immunityPoints)",
                correctPicksByUser: correctImmunityByUser,
                pointsPerCorrectPick: immunityPoints
            )
        )

        if includeMergeCategory {
            categories.append(
                Week.Category(
                    kind: .merge,
                    name: "Mergers",
                    pointsText: "1",
                    correctPicksByUser: mergeAliveByUser,
                    pointsPerCorrectPick: 1
                )
            )
        }

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
                let pointsPerPick = category.pointsPerCorrectPick.flatMap { $0 > 0 ? $0 : nil }
                let correctPicks = correctCustomByCategory[category.id] ?? [:]

                categories.append(
                    Week.Category(
                        kind: .custom(category.id),
                        name: name,
                        pointsText: pointsText,
                        correctPicksByUser: correctPicks,
                        pointsPerCorrectPick: pointsPerPick
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
                let pointsPerPick = category.pointsPerCorrectPick.flatMap { $0 > 0 ? $0 : nil }
                let correctPicks = correctCustomByCategory[id] ?? [:]

                categories.append(
                    Week.Category(
                        kind: .custom(id),
                        name: name,
                        pointsText: pointsText,
                        correctPicksByUser: correctPicks,
                        pointsPerCorrectPick: pointsPerPick
                    )
                )
            } else {
                let correctPicks = correctCustomByCategory[id] ?? [:]
                categories.append(
                    Week.Category(
                        kind: .custom(id),
                        name: "Category",
                        pointsText: "—",
                        correctPicksByUser: correctPicks,
                        pointsPerCorrectPick: nil
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
