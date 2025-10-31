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

    init(
        name: String,
        columnId: String,
        totalPicks: Int,
        pointsPerCorrectPick: Int?,
        wagerPoints: Int? = nil,
        isLocked: Bool,
        autoScoresRemainingContestants: Bool = false
    ) {
        self.name = name
        self.columnId = columnId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        self.totalPicks = totalPicks
        self.pointsPerCorrectPick = pointsPerCorrectPick
        self.wagerPoints = wagerPoints
        self.isLocked = isLocked
        self.autoScoresRemainingContestants = autoScoresRemainingContestants
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
            isLocked: isLocked
        )
    }
}

extension CategoryPreset {
    static let all: [CategoryPreset] = [
        CategoryPreset(name: "Mergers",         columnId: "MG", totalPicks: 3, pointsPerCorrectPick: 1,  isLocked: true, autoScoresRemainingContestants: true),
        CategoryPreset(name: "Immunity",        columnId: "IM", totalPicks: 3, pointsPerCorrectPick: 1,  isLocked: false),
        CategoryPreset(name: "Voted Out",       columnId: "VO", totalPicks: 3, pointsPerCorrectPick: 3,  isLocked: false),
        CategoryPreset(name: "Reward Challenge", columnId: "RC", totalPicks: 2, pointsPerCorrectPick: 5, isLocked: false),
        CategoryPreset(name: "Remains",         columnId: "RM", totalPicks: 3, pointsPerCorrectPick: 1,  isLocked: false, autoScoresRemainingContestants: true),
        CategoryPreset(name: "Final 3",         columnId: "F3", totalPicks: 3, pointsPerCorrectPick: 5, isLocked: true, autoScoresRemainingContestants: true),
        CategoryPreset(name: "Carried",         columnId: "CA", totalPicks: 1, pointsPerCorrectPick: 10, isLocked: false),
        CategoryPreset(name: "Fire",            columnId: "FI", totalPicks: 2, pointsPerCorrectPick: 10, isLocked: false),
        CategoryPreset(name: "Fire Winner",     columnId: "FW", totalPicks: 1, pointsPerCorrectPick: 15, isLocked: false),
        CategoryPreset(name: "Sole Survivor",   columnId: "SS", totalPicks: 1, pointsPerCorrectPick: 30, isLocked: false)
    ]
}

