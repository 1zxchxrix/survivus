import SwiftUI
//import struct survivus.LimitedMultiSelect
//import struct survivus.LockPill

// MARK: - Utilities

func picksLocked(for episode: Episode?) -> Bool {
    guard episode != nil else { return true }
    return false
}
