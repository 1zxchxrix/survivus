import Foundation

extension PickPhase.Category {
    var normalizedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var matchesImmunityCategory: Bool {
        normalizedName.contains("immunity")
    }

    var matchesVotedOutCategory: Bool {
        normalizedName.contains("voted")
    }

    var matchesRemainCategory: Bool {
        normalizedName.contains("remain") || normalizedName.contains("safe")
    }

    var matchesMergeCategory: Bool {
        normalizedName.contains("merge")
    }

    var matchesFinalThreeCategory: Bool {
        normalizedName.contains("final") && (normalizedName.contains("three") || normalizedName.contains("3"))
    }

    var matchesWinnerCategory: Bool {
        let winnerPhrases: [String] = [
            "sole survivor",
            "survivor winner",
            "season winner",
            "winner",
            "winner pick"
        ]

        return winnerPhrases.contains(normalizedName) ||
            (normalizedName.contains("sole") && normalizedName.contains("survivor")) ||
            normalizedName.contains("winner pick")
    }
}

extension PickPhase {
    fileprivate func pointsPerCorrectPick(matching predicate: (PickPhase.Category) -> Bool) -> Int? {
        guard let category = categories.first(where: predicate),
              let points = category.pointsPerCorrectPick,
              points > 0 else {
            return nil
        }
        return points
    }

    var remainPointsPerCorrectPick: Int? {
        pointsPerCorrectPick { $0.matchesRemainCategory }
    }

    var votedOutPointsPerCorrectPick: Int? {
        pointsPerCorrectPick { $0.matchesVotedOutCategory }
    }

    var immunityPointsPerCorrectPick: Int? {
        pointsPerCorrectPick { $0.matchesImmunityCategory }
    }
}
