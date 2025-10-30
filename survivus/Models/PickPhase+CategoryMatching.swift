import Foundation

extension PickPhase.Category {
    var matchesImmunityCategory: Bool { kind == .immunity }

    var matchesVotedOutCategory: Bool { kind == .votedOut }

    var matchesRemainCategory: Bool { kind == .remain }
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
