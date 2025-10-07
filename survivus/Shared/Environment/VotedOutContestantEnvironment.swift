import SwiftUI

private struct VotedOutContestantIDsKey: EnvironmentKey {
    static let defaultValue: Set<String> = []
}

extension EnvironmentValues {
    var votedOutContestantIDs: Set<String> {
        get { self[VotedOutContestantIDsKey.self] }
        set { self[VotedOutContestantIDsKey.self] = newValue }
    }
}
