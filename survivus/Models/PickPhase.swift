import Foundation

struct PickPhase: Identifiable, Equatable {
    struct Category: Identifiable, Equatable {
        let id: UUID
        var name: String
        var totalPicks: Int
        var pointsPerCorrectPick: Int?
        var isLocked: Bool

        init(
            id: UUID = UUID(),
            name: String,
            totalPicks: Int,
            pointsPerCorrectPick: Int?,
            isLocked: Bool
        ) {
            self.id = id
            self.name = name
            self.totalPicks = totalPicks
            self.pointsPerCorrectPick = pointsPerCorrectPick
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
                .init(name: "Mergers", totalPicks: 3, pointsPerCorrectPick: 1, isLocked: true),
                .init(name: "Immunity", totalPicks: 3, pointsPerCorrectPick: 3, isLocked: false),
                .init(name: "Voted out", totalPicks: 3, pointsPerCorrectPick: 3, isLocked: false)
            ]
        ),
        PickPhase(
            name: "Post-merge",
            categories: [
                .init(name: "Immunity", totalPicks: 2, pointsPerCorrectPick: 5, isLocked: false),
                .init(name: "Voted out", totalPicks: 2, pointsPerCorrectPick: 5, isLocked: false)
            ]
        ),
        PickPhase(
            name: "Finals",
            categories: [
                .init(name: "Carried", totalPicks: 1, pointsPerCorrectPick: 10, isLocked: false),
                .init(name: "Fire", totalPicks: 2, pointsPerCorrectPick: 10, isLocked: false),
                .init(name: "Fire winner", totalPicks: 1, pointsPerCorrectPick: 15, isLocked: false),
                .init(name: "Sole Survivor", totalPicks: 1, pointsPerCorrectPick: 25, isLocked: false)
            ]
        )
    ]

    static var preview: PickPhase {
        PickPhase(
            name: "Week 1",
            categories: [
                .init(name: "Immunity", totalPicks: 1, pointsPerCorrectPick: 2, isLocked: false),
                .init(name: "Voted Out", totalPicks: 2, pointsPerCorrectPick: 3, isLocked: false),
                .init(name: "Reward Challenge", totalPicks: 3, pointsPerCorrectPick: nil, isLocked: false),
                .init(name: "Locked Category", totalPicks: 1, pointsPerCorrectPick: nil, isLocked: true)
            ]
        )
    }
}

extension PickPhase.Category {
    init(from draft: CategoryDraft) {
        self.init(
            id: draft.id,
            name: draft.name,
            totalPicks: draft.totalPicks,
            pointsPerCorrectPick: draft.pointsPerCorrectPick,
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
    var totalPicks: Int
    var pointsPerCorrectPick: Int?
    var isLocked: Bool

    init(
        id: UUID = UUID(),
        name: String = "",
        totalPicks: Int = 1,
        pointsPerCorrectPick: Int? = nil,
        isLocked: Bool = false
    ) {
        self.id = id
        self.name = name
        self.totalPicks = totalPicks
        self.pointsPerCorrectPick = pointsPerCorrectPick
        self.isLocked = isLocked
    }

    init(from category: PickPhase.Category) {
        self.init(
            id: category.id,
            name: category.name,
            totalPicks: category.totalPicks,
            pointsPerCorrectPick: category.pointsPerCorrectPick,
            isLocked: category.isLocked
        )
    }
}
