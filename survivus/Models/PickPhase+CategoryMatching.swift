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
