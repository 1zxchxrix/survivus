import Foundation

struct CategoryPreset: Identifiable, Equatable {
    let id: String
    let name: String
    let columnId: String
    let totalPicks: Int
    let pointsPerCorrectPick: Int?
    let wagerPoints: Int?
    let isLocked: Bool
    let autoScoresRemainingContestants: Bool
    let kind: PickPhase.Category.Kind

    init(
        name: String,
        columnId: String,
        totalPicks: Int,
        pointsPerCorrectPick: Int?,
        wagerPoints: Int? = nil,
        isLocked: Bool,
        autoScoresRemainingContestants: Bool = false,
        kind: PickPhase.Category.Kind = .custom
    ) {
        self.name = name
        self.columnId = columnId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        self.totalPicks = totalPicks
        self.pointsPerCorrectPick = pointsPerCorrectPick
        self.wagerPoints = wagerPoints
        self.isLocked = isLocked
        self.autoScoresRemainingContestants = autoScoresRemainingContestants
        self.kind = kind
        self.id = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    func makeDraft() -> CategoryDraft {
        CategoryDraft(
            name: name,
            columnId: columnId,
            totalPicks: totalPicks,
            pointsPerCorrectPick: pointsPerCorrectPick,
            wagerPoints: wagerPoints,
            autoScoresRemainingContestants: autoScoresRemainingContestants,
            isLocked: isLocked,
            kind: kind
        )
    }
}

extension CategoryPreset {
    static let all: [CategoryPreset] = [
        CategoryPreset(name: "Mergers", columnId: "MG", totalPicks: 3, pointsPerCorrectPick: 1, isLocked: true),
        CategoryPreset(name: "Immunity", columnId: "IM", totalPicks: 3, pointsPerCorrectPick: 1, isLocked: false, kind: .immunity),
        CategoryPreset(name: "Voted out", columnId: "VO", totalPicks: 3, pointsPerCorrectPick: 3, isLocked: false, kind: .votedOut),
        CategoryPreset(name: "Remains", columnId: "RM", totalPicks: 3, pointsPerCorrectPick: 1, isLocked: false, kind: .remain),
        CategoryPreset(name: "Carried", columnId: "CA", totalPicks: 1, pointsPerCorrectPick: 10, isLocked: false),
        CategoryPreset(name: "Fire", columnId: "FI", totalPicks: 2, pointsPerCorrectPick: 10, isLocked: false),
        CategoryPreset(name: "Fire Winner", columnId: "FW", totalPicks: 1, pointsPerCorrectPick: 15, isLocked: false),
        CategoryPreset(name: "Sole Survivor", columnId: "SS", totalPicks: 1, pointsPerCorrectPick: nil, wagerPoints: 30, isLocked: false)
    ]
}
