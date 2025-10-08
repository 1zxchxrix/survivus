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
