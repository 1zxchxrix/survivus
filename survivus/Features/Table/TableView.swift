import SwiftUI

struct TableView: View {
    @EnvironmentObject var app: AppState
    var body: some View {
        let config = app.store.config
        let scoring = app.scoring
        let recordedResults = app.store.results.filter(\.hasRecordedResults)
        let lastEpisodeWithResult = recordedResults.map { $0.id }.max() ?? 0
        let usersById = Dictionary(uniqueKeysWithValues: app.store.users.map { ($0.id, $0) })
        let activeColumnIDs = makeActiveColumnIDs(from: app.phases, activatedPhaseIDs: app.activatedPhaseIDs)
        let dynamicColumns = makeDynamicColumns(from: app.phases, activeColumnIDs: activeColumnIDs)
        var columnDefinitions: [TableColumnDefinition] = [
            TableColumnDefinition.totalPoints,
            TableColumnDefinition.weeksParticipated
        ]
        columnDefinitions.append(contentsOf: dynamicColumns)
        let legendEntries = columnDefinitions.map(\.legendEntry)
        let categoriesById = Dictionary(uniqueKeysWithValues: app.phases.flatMap { phase in
            phase.categories.map { ($0.id, $0) }
        })
        let phasesById = Dictionary(uniqueKeysWithValues: app.phases.map { ($0.id, $0) })
        let phaseByEpisodeId: [Int: PickPhase] = Dictionary(uniqueKeysWithValues: recordedResults.compactMap { result in
            guard let phaseId = result.phaseId, let phase = phasesById[phaseId] else { return nil }
            return (result.id, phase)
        })
        let isMergeCategoryActive: (Int) -> Bool = { episodeId in
            guard let phase = phaseByEpisodeId[episodeId] else { return true }
            return phase.categories.contains { $0.matchesMergeCategory }
        }
        let episodesById = Dictionary(uniqueKeysWithValues: config.episodes.map { ($0.id, $0) })
        let scoredEpisodeIds = recordedResults.map(\.id).sorted()
        let pinnedColumns = columnDefinitions.filter { $0.isPinned }
        let scrollableColumns = columnDefinitions.filter { !$0.isPinned }
        let nameColumnWidth: CGFloat = 120
        let columnSpacing: CGFloat = 4
        let tableHorizontalPadding: CGFloat = 12
        let pinnedToScrollableSpacing: CGFloat = tableHorizontalPadding
        let rowContentMinHeight: CGFloat = 32
        let pinnedSectionWidth = pinnedColumns.reduce(nameColumnWidth) { partialWidth, column in
            partialWidth + columnSpacing + column.width
        }
        
        let breakdowns: [UserScoreBreakdown] = app.store.users.map { user in
            var votedOutPoints = 0
            var remainPoints = 0
            var immunityPoints = 0
            var weeksParticipated = 0
            var categoryPoints: [String: Int] = [:]
            
            for episodeId in scoredEpisodeIds {
                let episode = episodesById[episodeId] ?? Episode(id: episodeId)
                if let picks = app.store.weeklyPicks[user.id]?[episodeId] {
                    weeksParticipated += 1
                    let activePhase = phaseByEpisodeId[episodeId]
                    let score = scoring.score(weekly: picks, episode: episode, phaseOverride: activePhase, categoriesById: categoriesById)
                    votedOutPoints += score.votedOut
                    remainPoints += score.remain
                    immunityPoints += score.immunity
                    for (columnId, points) in score.categoryPointsByColumnId {
                        categoryPoints[columnId, default: 0] += points
                    }
                }
            }
            
            let season = app.store.seasonPicks[user.id] ?? SeasonPicks(userId: user.id)
            let mergePoints = scoring.mergeTrackPoints(
                for: user.id,
                upTo: lastEpisodeWithResult,
                seasonPicks: season,
                isCategoryActive: isMergeCategoryActive
            )
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
            VStack(alignment: .leading, spacing: 12) {
                ScrollView(.vertical) {
                    Group {
                        if scrollableColumns.isEmpty {
                            TablePinnedSection(
                                pinnedColumns: pinnedColumns,
                                breakdowns: breakdowns,
                                usersById: usersById,
                                nameColumnWidth: nameColumnWidth,
                                pinnedSectionWidth: pinnedSectionWidth,
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
                                    pinnedSectionWidth: pinnedSectionWidth,
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
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Spacer()
                            NavigationLink {
                                ScoreDetailsView()
                            } label: {
                                HStack(spacing: 4) {
                                    Text("Details")
                                    Image(systemName: "chevron.right")
                                }
                                .fontWeight(.semibold)
                            }
                        }
                        
                        if !legendEntries.isEmpty {
                            Text(legendEntries.joined(separator: "\n"))
                                .font(.footnote)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.top, 12)
                    .padding(.horizontal, tableHorizontalPadding)
                    .padding(.bottom, 16)
                }
                .navigationTitle("Table")
            }
        }
        
    }
    
    private func makeActiveColumnIDs(from phases: [PickPhase], activatedPhaseIDs: Set<PickPhase.ID>) -> Set<String> {
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
    
    private func makeDynamicColumns(from phases: [PickPhase], activeColumnIDs: Set<String>) -> [TableColumnDefinition] {
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
                let metric = TableColumnDefinition.Metric(category: category)
                let legendDescription = TableColumnDefinition.legendDescription(for: metric, category: category)
                result.append(
                    TableColumnDefinition(
                        id: trimmedId,
                        title: trimmedId,
                        width: 48,
                        metric: metric,
                        legendDescription: legendDescription,
                        isActive: activeColumnIDs.contains(trimmedId),
                        isPinned: false
                    )
                )
            }
        }
        
        return result
    }
    
    private struct TablePinnedSection: View {
        let pinnedColumns: [TableColumnDefinition]
        let breakdowns: [UserScoreBreakdown]
        let usersById: [UserProfile.ID: UserProfile]
        let nameColumnWidth: CGFloat
        let pinnedSectionWidth: CGFloat
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
            .frame(width: pinnedSectionWidth, alignment: .leading)
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
                        avatarView(for: user, size: avatarSize)
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
        
        private func avatarView(for user: UserProfile, size: CGFloat) -> some View {
            Group {
                if let url = user.avatarURL {
                    StorageAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        avatarPlaceholder(size: size)
                    }
                } else {
                    avatarPlaceholder(size: size)
                }
            }
        }
        
        @ViewBuilder
        private func avatarPlaceholder(size: CGFloat) -> some View {
            Image(systemName: "person.fill")
                .resizable()
                .scaledToFit()
                .padding(size * 0.3)
                .foregroundStyle(.secondary)
        }
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
        let legendDescription: String
        let isActive: Bool
        let isPinned: Bool
        
        var legendEntry: String {
            "\(id): \(legendDescription)"
        }
        
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
        static let weeksParticipated = TableColumnDefinition(
            id: "Wk",
            title: "Wk",
            width: 40,
            metric: .weeks,
            legendDescription: "Weeks participated",
            isActive: true,
            isPinned: false
        )
        
        static let totalPoints = TableColumnDefinition(
            id: "Pts",
            title: "Pts",
            width: 52,
            metric: .total,
            legendDescription: "Total points",
            isActive: true,
            isPinned: true
        )
        
        static func legendDescription(for metric: Metric?, category: PickPhase.Category?) -> String {
            let trimmedCategoryName = category?.name.trimmingCharacters(in: .whitespacesAndNewlines)
            
            switch metric {
            case .weeks:
                return "Weeks participated"
            case .votedOut:
                return "Voted out points"
            case .remain:
                return "Remain points"
            case .immunity:
                return "Immunity points"
            case .merge:
                return "Mergers points"
            case .finalThree:
                return "Final three track points"
            case .winner:
                return "Winner points"
            case .total:
                return "Total points"
            case .custom:
                if let name = trimmedCategoryName, !name.isEmpty {
                    return name
                }
                return "Custom scoring"
            case nil:
                if let name = trimmedCategoryName, !name.isEmpty {
                    return name
                }
                return "Custom scoring"
            }
        }
    }
}
