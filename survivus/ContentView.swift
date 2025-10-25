import SwiftUI

// MARK: - Utilities

func picksLocked(for episode: Episode?, userId: String, store: MemoryStore) -> Bool {
    guard let episode else { return true }
    return store.isWeeklyPicksLocked(for: userId, episodeId: episode.id)
}
