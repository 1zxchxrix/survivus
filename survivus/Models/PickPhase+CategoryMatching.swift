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
