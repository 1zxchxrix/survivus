import SwiftUI

struct TableView: View {
    @EnvironmentObject var app: AppState
    @State private var horizontalScrollOffset: CGFloat = 0

    var body: some View {
        let config = app.store.config
        let scoring = app.scoring
        let lastEpisodeWithResult = app.store.results.map { $0.id }.max() ?? 0
        let usersById = Dictionary(uniqueKeysWithValues: app.store.users.map { ($0.id, $0) })
        let dynamicColumns = columns(from: app.phases)
        let columns: [TableColumnDefinition] = [.totalPoints, .weeksParticipated] + dynamicColumns
        let pinnedColumns = columns.first.map { [$0] } ?? []
        let scrollableColumns = Array(columns.dropFirst())
        let nameColumnMinWidth: CGFloat = 160
        let columnSpacing: CGFloat = 4

        let breakdowns: [UserScoreBreakdown] = app.store.users.map { user in
            var votedOutPoints = 0
            var remainPoints = 0
            var immunityPoints = 0
            var weeksParticipated = 0

            for episode in config.episodes where episode.id <= lastEpisodeWithResult {
                if let picks = app.store.weeklyPicks[user.id]?[episode.id] {
                    weeksParticipated += 1
                    let score = scoring.score(weekly: picks, episode: episode)
                    votedOutPoints += score.votedOut
                    remainPoints += score.remain
                    immunityPoints += score.immunity
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
                winnerPoints: winnerPoints
            )
        }
        .sorted { $0.total > $1.total }

        return NavigationStack {
            GeometryReader { proxy in
                ScrollView([.vertical, .horizontal]) {
                    VStack(spacing: 0) {
                        TableHeader(
                            pinnedColumns: pinnedColumns,
                            scrollableColumns: scrollableColumns,
                            nameColumnMinWidth: nameColumnMinWidth,
                            columnSpacing: columnSpacing,
                            horizontalOffset: horizontalScrollOffset
                        )
                        .padding(.horizontal)
                        .padding(.vertical, 8)

                        if !breakdowns.isEmpty {
                            Divider()
                        }

                        ForEach(Array(breakdowns.enumerated()), id: \.element.id) { index, breakdown in
                            if index > 0 {
                                Divider()
                            }

                            TableRow(
                                breakdown: breakdown,
                                user: usersById[breakdown.userId],
                                pinnedColumns: pinnedColumns,
                                scrollableColumns: scrollableColumns,
                                nameColumnMinWidth: nameColumnMinWidth,
                                columnSpacing: columnSpacing,
                                horizontalOffset: horizontalScrollOffset
                            )
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .frame(minHeight: proxy.size.height, alignment: .top)
                }
                .coordinateSpace(name: "tableScroll")
                .onPreferenceChange(HorizontalScrollOffsetKey.self) { horizontalScrollOffset = $0 }
                .background(Color(.systemGroupedBackground))
            }
            .navigationTitle("Table")
        }
    }

    private func columns(from phases: [PickPhase]) -> [TableColumnDefinition] {
        var seenIds: Set<String> = [
            TableColumnDefinition.weeksParticipated.id.uppercased(),
            TableColumnDefinition.totalPoints.id.uppercased()
        ]
        var result: [TableColumnDefinition] = []

        for phase in phases {
            for category in phase.categories {
                let trimmedId = category.columnId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                guard !trimmedId.isEmpty, !seenIds.contains(trimmedId) else { continue }
                guard let metric = TableColumnDefinition.Metric(category: category) else { continue }

                seenIds.insert(trimmedId)
                result.append(
                    TableColumnDefinition(
                        id: trimmedId,
                        title: trimmedId,
                        width: 48,
                        metric: metric
                    )
                )
            }
        }

        return result
    }
}

private struct TableHeader: View {
    let pinnedColumns: [TableColumnDefinition]
    let scrollableColumns: [TableColumnDefinition]
    let nameColumnMinWidth: CGFloat
    let columnSpacing: CGFloat
    let horizontalOffset: CGFloat

    private var pinnedContent: some View {
        HStack(spacing: columnSpacing) {
            Text("Name")
                .font(.subheadline.weight(.semibold))
                .frame(minWidth: nameColumnMinWidth, alignment: .leading)

            ForEach(pinnedColumns) { column in
                Text(column.title)
                    .font(.footnote.weight(.semibold))
                    .frame(width: column.width, alignment: .center)
            }
        }
    }

    var body: some View {
        HStack(spacing: columnSpacing) {
            pinnedContent.hidden()

            ForEach(scrollableColumns) { column in
                Text(column.title)
                    .font(.footnote.weight(.semibold))
                    .frame(width: column.width, alignment: .center)
            }
        }
        .overlay(alignment: .leading) {
            pinnedContent
                .offset(x: horizontalOffset)
                .background(Color(.systemGroupedBackground))
                .allowsHitTesting(false)
        }
        .foregroundStyle(.secondary)
        .background(
            GeometryReader { proxy in
                Color.clear
                    .preference(
                        key: HorizontalScrollOffsetKey.self,
                        value: -proxy.frame(in: .named("tableScroll")).minX
                    )
            }
        )
    }
}

private struct TableRow: View {
    let breakdown: UserScoreBreakdown
    let user: UserProfile?
    let pinnedColumns: [TableColumnDefinition]
    let scrollableColumns: [TableColumnDefinition]
    let nameColumnMinWidth: CGFloat
    let columnSpacing: CGFloat
    let horizontalOffset: CGFloat

    private var pinnedContent: some View {
        HStack(spacing: columnSpacing) {
            HStack(spacing: 8) {
                if let user {
                    Image(user.avatarAssetName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                        .accessibilityHidden(true)

                    Text(user.displayName)
                        .font(.subheadline)
                        .lineLimit(1)
                        .layoutPriority(1)
                } else {
                    Text(breakdown.userId)
                        .font(.subheadline)
                        .lineLimit(1)
                        .layoutPriority(1)
                }
            }
            .frame(minWidth: nameColumnMinWidth, alignment: .leading)

            ForEach(pinnedColumns) { column in
                Text(column.displayValue(for: breakdown))
                    .font(.subheadline.weight(column.metric == .total ? .semibold : .regular))
                    .frame(width: column.width, alignment: .center)
            }
        }
    }

    var body: some View {
        HStack(spacing: columnSpacing) {
            pinnedContent.hidden()

            ForEach(scrollableColumns) { column in
                Text(column.displayValue(for: breakdown))
                    .font(.subheadline.weight(column.metric == .total ? .semibold : .regular))
                    .frame(width: column.width, alignment: .center)
            }
        }
        .overlay(alignment: .leading) {
            pinnedContent
                .offset(x: horizontalOffset)
                .background(Color(.systemGroupedBackground))
                .allowsHitTesting(false)
        }
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
                return nil
            }
        }
    }

    let id: String
    let title: String
    let width: CGFloat
    let metric: Metric

    func displayValue(for breakdown: UserScoreBreakdown) -> String {
        String(value(for: breakdown))
    }

    private func value(for breakdown: UserScoreBreakdown) -> Int {
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
        }
    }
}

private extension TableColumnDefinition {
    static let weeksParticipated = TableColumnDefinition(id: "Wk", title: "Wk", width: 40, metric: .weeks)
    static let totalPoints = TableColumnDefinition(id: "Pts", title: "Pts", width: 52, metric: .total)
}

private struct HorizontalScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
