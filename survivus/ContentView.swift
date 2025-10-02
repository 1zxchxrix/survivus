import SwiftUI
import struct survivus.LimitedMultiSelect
import struct survivus.LockPill

// MARK: - Utilities

func picksLocked(for episode: Episode?) -> Bool {
    guard let episode else { return true }
    // Demo lock: disable once airDate has passed
    return Date() >= episode.airDate
}
