import Foundation

struct PickPhase: Identifiable, Equatable {
    struct Category: Identifiable, Equatable {
        let id: UUID
        var name: String
        var columnId: String
        var totalPicks: Int
        var pointsPerCorrectPick: Int?
        var wagerPoints: Int?
        var autoScoresRemainers: Bool
        var isLocked: Bool

        init(
            id: UUID = UUID(),
            name: String,
            columnId: String,
            totalPicks: Int,
            pointsPerCorrectPick: Int?,
            wagerPoints: Int?,
            autoScoresRemainers: Bool,
            isLocked: Bool
        ) {
            self.id = id
            self.name = name
            let trimmedColumnId = columnId.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedColumnId.isEmpty {
                self.columnId = columnId
            } else {
                self.columnId = trimmedColumnId.uppercased()
            }
            self.totalPicks = totalPicks
            self.pointsPerCorrectPick = pointsPerCorrectPick
            self.wagerPoints = wagerPoints
            self.autoScoresRemainers = autoScoresRemainers
            self.isLocked = isLocked
        }
    }

    let id: UUID
    var name: String
    var categories: [Category]

    init(id: UUID = UUID(), name: String, categories: [Category]) {
        self.id = id
        self.name = name
        self.categories = categories
    }
}

extension PickPhase {
    static let preconfigured: [PickPhase] = [
        PickPhase(
            name: "Pre-merge",
            categories: [
                .init(name: "Mergers", columnId: "MG", totalPicks: 3, pointsPerCorrectPick: 1, wagerPoints: nil, autoScoresRemainers: false, isLocked: true),
                .init(name: "Immunity", columnId: "IM", totalPicks: 3, pointsPerCorrectPick: 3, wagerPoints: nil, autoScoresRemainers: false, isLocked: false),
                .init(name: "Voted out", columnId: "VO", totalPicks: 3, pointsPerCorrectPick: 3, wagerPoints: nil, autoScoresRemainers: false, isLocked: false)
            ]
        ),
        PickPhase(
            name: "Post-merge",
            categories: [
                .init(name: "Immunity", columnId: "IM", totalPicks: 2, pointsPerCorrectPick: 5, wagerPoints: nil, autoScoresRemainers: false, isLocked: false),
                .init(name: "Voted out", columnId: "VO", totalPicks: 2, pointsPerCorrectPick: 5, wagerPoints: nil, autoScoresRemainers: false, isLocked: false)
            ]
        ),
        PickPhase(
            name: "Finals",
            categories: [
                .init(name: "Carried", columnId: "CA", totalPicks: 1, pointsPerCorrectPick: 10, wagerPoints: nil, autoScoresRemainers: false, isLocked: false),
                .init(name: "Fire", columnId: "FI", totalPicks: 2, pointsPerCorrectPick: 10, wagerPoints: nil, autoScoresRemainers: false, isLocked: false),
                .init(name: "Fire Winner", columnId: "FW", totalPicks: 1, pointsPerCorrectPick: 15, wagerPoints: nil, autoScoresRemainers: false, isLocked: false),
                .init(name: "Sole Survivor", columnId: "SS", totalPicks: 1, pointsPerCorrectPick: nil, wagerPoints: 30, autoScoresRemainers: false, isLocked: false)
            ]
        )
    ]

    static var preview: PickPhase {
        PickPhase(
            name: "Week 1",
            categories: [
                .init(name: "Immunity", columnId: "IM", totalPicks: 1, pointsPerCorrectPick: 2, wagerPoints: nil, autoScoresRemainers: false, isLocked: false),
                .init(name: "Voted Out", columnId: "VO", totalPicks: 2, pointsPerCorrectPick: 3, wagerPoints: nil, autoScoresRemainers: false, isLocked: false),
                .init(name: "Reward Challenge", columnId: "RC", totalPicks: 3, pointsPerCorrectPick: nil, wagerPoints: nil, autoScoresRemainers: false, isLocked: false),
                .init(name: "Locked Category", columnId: "LC", totalPicks: 1, pointsPerCorrectPick: nil, wagerPoints: nil, autoScoresRemainers: false, isLocked: true)
            ]
        )
    }
}

extension PickPhase.Category {
    init(from draft: CategoryDraft) {
        self.init(
            id: draft.id,
            name: draft.name,
            columnId: draft.columnId,
            totalPicks: draft.totalPicks,
            pointsPerCorrectPick: draft.usesWager ? nil : draft.pointsPerCorrectPick,
            wagerPoints: draft.usesWager ? draft.wagerPoints : nil,
            autoScoresRemainers: draft.autoScoresRemainers,
            isLocked: draft.isLocked
        )
    }

    init(_ draft: CategoryDraft) {
        self.init(from: draft)
    }
}

struct CategoryDraft: Identifiable, Equatable {
    let id: UUID
    var name: String
    var columnId: String
    var totalPicks: Int
    var pointsPerCorrectPick: Int?
    var wagerPoints: Int?
    var usesWager: Bool
    var autoScoresRemainers: Bool
    var isLocked: Bool

    init(
        id: UUID = UUID(),
        name: String = "",
        columnId: String = "",
        totalPicks: Int = 1,
        pointsPerCorrectPick: Int? = nil,
        wagerPoints: Int? = nil,
        usesWager: Bool = false,
        autoScoresRemainers: Bool = false,
        isLocked: Bool = false
    ) {
        self.id = id
        self.name = name
        self.columnId = columnId
        self.totalPicks = totalPicks
        self.pointsPerCorrectPick = pointsPerCorrectPick
        self.wagerPoints = wagerPoints
        self.usesWager = usesWager || wagerPoints != nil
        self.autoScoresRemainers = autoScoresRemainers
        self.isLocked = isLocked
    }

    init(from category: PickPhase.Category) {
        self.init(
            id: category.id,
            name: category.name,
            columnId: category.columnId,
            totalPicks: category.totalPicks,
            pointsPerCorrectPick: category.pointsPerCorrectPick,
            wagerPoints: category.wagerPoints,
            usesWager: category.wagerPoints != nil,
            autoScoresRemainers: category.autoScoresRemainers,
            isLocked: category.isLocked
        )
    }
}
