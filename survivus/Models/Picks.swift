import Foundation

struct WeeklyPicks: Identifiable, Hashable, Codable {
    var id: String { "\(userId)-ep-\(episodeId)" }
    let userId: String
    let episodeId: Int
    var categorySelections: [UUID: Set<String>] = [:]
    var categoryWagers: [UUID: Int] = [:]
    var isSubmitted: Bool = false

    func selections(for categoryId: UUID) -> Set<String> {
        categorySelections[categoryId] ?? []
    }

    mutating func setSelections(_ selections: Set<String>, for categoryId: UUID) {
        if selections.isEmpty {
            categorySelections.removeValue(forKey: categoryId)
        } else {
            categorySelections[categoryId] = selections
        }
    }

    func wager(for categoryId: UUID) -> Int? {
        categoryWagers[categoryId]
    }

    mutating func setWager(_ wager: Int?, for categoryId: UUID) {
        guard let wager else {
            categoryWagers.removeValue(forKey: categoryId)
            return
        }

        categoryWagers[categoryId] = wager
    }
}
