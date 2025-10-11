import SwiftUI

struct TableView: View {
    @EnvironmentObject var app: AppState
    var body: some View {
        let config = app.store.config
        let scoring = app.scoring
        let lastEpisodeWithResult = app.store.results.map { $0.id }.max() ?? 0
        let usersById = Dictionary(uniqueKeysWithValues: app.store.users.map { ($0.id, $0) })
        let activeColumnIDs = activeColumnIDs(from: app.phases, activatedPhaseIDs: app.activatedPhaseIDs)
        let dynamicColumns = columns(from: app.phases, activeColumnIDs: activeColumnIDs)
        let columns: [TableColumnDefinition] = [.totalPoints, .weeksParticipated] + dynamicColumns
        let categoriesById = Dictionary(uniqueKeysWithValues: app.phases.flatMap { phase in
            phase.categories.map { ($0.id, $0) }
        })
        let pinnedColumns = columns.filter { $0.isPinned }
        let scrollableColumns = columns.filter { !$0.isPinned }
        let nameColumnWidth: CGFloat = 120
        let columnSpacing: CGFloat = 4
        let tableHorizontalPadding: CGFloat = 12
        let pinnedToScrollableSpacing: CGFloat = tableHorizontalPadding
        let rowContentMinHeight: CGFloat = 32

        let breakdowns: [UserScoreBreakdown] = app.store.users.map { user in
            var votedOutPoints = 0
            var remainPoints = 0
            var immunityPoints = 0
            var weeksParticipated = 0
            var categoryPoints: [String: Int] = [:]

            for episode in config.episodes where episode.id <= lastEpisodeWithResult {
                if let picks = app.store.weeklyPicks[user.id]?[episode.id] {
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

            let season = app.store.seasonPicks[user.id] ?? SeasonPicks(userId: user.id)
            let mergePoints = scoring.mergeTrackPoints(for: user.id, upTo: lastEpisodeWithResult, seasonPicks: season)
            let finalThreePoints = scoring.finalThreeTrackPoints(for: user.id, upTo: lastEpisodeWithResult, seasonPicks: season)
            let winnerPoints = scoring.winnerPoints(seasonPicks: season, finalResult: nil)

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

        return NavigationStack {
            ScrollView(.vertical) {
                Group {
                    if scrollableColumns.isEmpty {
                        TablePinnedSection(
                            pinnedColumns: pinnedColumns,
                            breakdowns: breakdowns,
                            usersById: usersById,
                            nameColumnWidth: nameColumnWidth,
                            columnSpacing: columnSpacing,
                            rowContentMinHeight: rowContentMinHeight,
                            showsTrailingSeparator: false
                        )
                    } else {
                        HStack(alignment: .top, spacing: pinnedToScrollableSpacing) {
                            TablePinnedSection(
                                pinnedColumns: pinnedColumns,
                                breakdowns: breakdowns,
                                usersById: usersById,
                                nameColumnWidth: nameColumnWidth,
                                columnSpacing: columnSpacing,
                                rowContentMinHeight: rowContentMinHeight,
                                showsTrailingSeparator: true
                            )

                            ScrollView(.horizontal) {
                                TableScrollableSection(
                                    scrollableColumns: scrollableColumns,
                                    breakdowns: breakdowns,
                                    columnSpacing: columnSpacing,
                                    rowContentMinHeight: rowContentMinHeight
                                )
                            }
                            .background(Color(.systemGroupedBackground))
                        }
                    }
                }
                .padding(.horizontal, tableHorizontalPadding)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGroupedBackground))
            }
            .navigationTitle("Table")
        }
    }

    private func activeColumnIDs(from phases: [PickPhase], activatedPhaseIDs: Set<PickPhase.ID>) -> Set<String> {
        var result: Set<String> = []

        for phase in phases where activatedPhaseIDs.contains(phase.id) {
            for category in phase.categories {
                let trimmedId = category.columnId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                guard !trimmedId.isEmpty else { continue }
                result.insert(trimmedId)
            }
        }

        return result
    }

    private func columns(from phases: [PickPhase], activeColumnIDs: Set<String>) -> [TableColumnDefinition] {
        var seenIds: Set<String> = [
            TableColumnDefinition.weeksParticipated.id.uppercased(),
            TableColumnDefinition.totalPoints.id.uppercased()
        ]
        var result: [TableColumnDefinition] = []

        for phase in phases {
            for category in phase.categories {
                let trimmedId = category.columnId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                guard !trimmedId.isEmpty, !seenIds.contains(trimmedId) else { continue }
                seenIds.insert(trimmedId)
                result.append(
                    TableColumnDefinition(
                        id: trimmedId,
                        title: trimmedId,
                        width: 48,
                        metric: TableColumnDefinition.Metric(category: category),
                        isActive: activeColumnIDs.contains(trimmedId),
                        isPinned: false
                    )
                )
            }
        }

        return result
    }
}

private struct TablePinnedSection: View {
    let pinnedColumns: [TableColumnDefinition]
    let breakdowns: [UserScoreBreakdown]
    let usersById: [UserProfile.ID: UserProfile]
    let nameColumnWidth: CGFloat
    let columnSpacing: CGFloat
    let rowContentMinHeight: CGFloat
    let showsTrailingSeparator: Bool

    var body: some View {
        VStack(spacing: 0) {
            TablePinnedHeader(
                pinnedColumns: pinnedColumns,
                nameColumnWidth: nameColumnWidth,
                columnSpacing: columnSpacing
            )
            .padding(.vertical, 8)

            if !breakdowns.isEmpty {
                Divider()
            }

            ForEach(Array(breakdowns.enumerated()), id: \.element.id) { index, breakdown in
                if index > 0 {
                    Divider()
                }

                TablePinnedRow(
                    breakdown: breakdown,
                    user: usersById[breakdown.userId],
                    pinnedColumns: pinnedColumns,
                    nameColumnWidth: nameColumnWidth,
                    columnSpacing: columnSpacing,
                    rowContentMinHeight: rowContentMinHeight
                )
                .padding(.vertical, 8)
            }
        }
        .background(Color(.systemGroupedBackground))
        .overlay(alignment: .trailing) {
            if showsTrailingSeparator {
                Color(.separator)
                    .frame(width: 1)
                    .opacity(0.5)
            }
        }
    }
}

private struct TableScrollableSection: View {
    let scrollableColumns: [TableColumnDefinition]
    let breakdowns: [UserScoreBreakdown]
    let columnSpacing: CGFloat
    let rowContentMinHeight: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            TableScrollableHeader(
                columns: scrollableColumns,
                columnSpacing: columnSpacing
            )
            .padding(.vertical, 8)

            if !breakdowns.isEmpty {
                Divider()
            }

            ForEach(Array(breakdowns.enumerated()), id: \.element.id) { index, breakdown in
                if index > 0 {
                    Divider()
                }

                TableScrollableRow(
                    breakdown: breakdown,
                    columns: scrollableColumns,
                    columnSpacing: columnSpacing,
                    rowContentMinHeight: rowContentMinHeight
                )
                .padding(.vertical, 8)
            }
        }
    }
}

private struct TablePinnedHeader: View {
    let pinnedColumns: [TableColumnDefinition]
    let nameColumnWidth: CGFloat
    let columnSpacing: CGFloat

    var body: some View {
        HStack(spacing: columnSpacing) {
            Text("Name")
                .font(.footnote.weight(.semibold))
                .frame(width: nameColumnWidth, alignment: .leading)

            ForEach(pinnedColumns) { column in
                Text(column.title)
                    .font(.footnote.weight(.semibold))
                    .frame(width: column.width, alignment: .center)
            }
        }
        .foregroundStyle(.secondary)
    }
}

private struct TableScrollableHeader: View {
    let columns: [TableColumnDefinition]
    let columnSpacing: CGFloat

    var body: some View {
        HStack(spacing: columnSpacing) {
            ForEach(columns) { column in
                Text(column.title)
                    .font(.footnote.weight(.semibold))
                    .frame(width: column.width, alignment: .center)
            }
        }
        .foregroundStyle(.secondary)
    }
}

private struct TablePinnedRow: View {
    let breakdown: UserScoreBreakdown
    let user: UserProfile?
    let pinnedColumns: [TableColumnDefinition]
    let nameColumnWidth: CGFloat
    let columnSpacing: CGFloat
    let rowContentMinHeight: CGFloat

    var body: some View {
        HStack(spacing: columnSpacing) {
            HStack(spacing: 8) {
                if let user {
                    Image(user.avatarAssetName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: avatarSize, height: avatarSize)
                        .clipShape(Circle())
                        .accessibilityHidden(true)

                    Text(user.displayName)
                        .font(.subheadline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                } else {
                    Text(breakdown.userId)
                        .font(.subheadline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(width: nameColumnWidth, alignment: .leading)
            .frame(minHeight: rowContentMinHeight, alignment: .center)

            ForEach(pinnedColumns) { column in
                Text(column.displayValue(for: breakdown))
                    .font(.subheadline.weight(column.metric == .some(.total) ? .semibold : .regular))
                    .frame(width: column.width, alignment: .center)
            }
        }
    }

    private var avatarSize: CGFloat { 32 }
}

private struct TableScrollableRow: View {
    let breakdown: UserScoreBreakdown
    let columns: [TableColumnDefinition]
    let columnSpacing: CGFloat
    let rowContentMinHeight: CGFloat

    var body: some View {
        HStack(spacing: columnSpacing) {
            ForEach(columns) { column in
                Text(column.displayValue(for: breakdown))
                    .font(.subheadline.weight(column.metric == .some(.total) ? .semibold : .regular))
                    .frame(width: column.width, alignment: .center)
            }
        }
        .frame(minHeight: rowContentMinHeight, alignment: .center)
    }
}

private struct TableColumnDefinition: Identifiable, Hashable {
    enum Metric: Hashable {
        case weeks
        case votedOut
        case remain
        case immunity
        case merge
        case finalThree
        case winner
        case total
        case custom(String)

        init?(category: PickPhase.Category) {
            if category.matchesRemainCategory {
                self = .remain
            } else if category.matchesVotedOutCategory {
                self = .votedOut
            } else if category.matchesImmunityCategory {
                self = .immunity
            } else if category.matchesMergeCategory {
                self = .merge
            } else if category.matchesFinalThreeCategory {
                self = .finalThree
            } else if category.matchesWinnerCategory {
                self = .winner
            } else {
                let trimmed = category.columnId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                guard !trimmed.isEmpty else { return nil }
                self = .custom(trimmed)
            }
        }
    }

    let id: String
    let title: String
    let width: CGFloat
    let metric: Metric?
    let isActive: Bool
    let isPinned: Bool

    func displayValue(for breakdown: UserScoreBreakdown) -> String {
        guard isActive else { return "-" }

        guard let metric else {
            return "0"
        }

        return String(value(for: breakdown, metric: metric))
    }

    private func value(for breakdown: UserScoreBreakdown, metric: Metric) -> Int {
        switch metric {
        case .weeks:
            return breakdown.weeksParticipated
        case .votedOut:
            return breakdown.votedOutPoints
        case .remain:
            return breakdown.remainPoints
        case .immunity:
            return breakdown.immunityPoints
        case .merge:
            return breakdown.mergeTrackPoints
        case .finalThree:
            return breakdown.finalThreeTrackPoints
        case .winner:
            return breakdown.winnerPoints
        case .total:
            return breakdown.total
        case let .custom(columnId):
            return breakdown.points(forColumnId: columnId)
        }
    }
}

private extension TableColumnDefinition {
    static let weeksParticipated = TableColumnDefinition(
        id: "Wk",
        title: "Wk",
        width: 40,
        metric: .weeks,
        isActive: true,
        isPinned: false
    )

    static let totalPoints = TableColumnDefinition(
        id: "Pts",
        title: "Pts",
        width: 52,
        metric: .total,
        isActive: true,
        isPinned: true
    )
}

