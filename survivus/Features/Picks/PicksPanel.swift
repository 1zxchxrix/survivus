import Foundation

enum SeasonPickPanel: Hashable {
    case merge
    case finalThree
    case winner
}

enum WeeklyPickPanel: Hashable {
    case remain
    case votedOut
    case immunity
}

enum PicksPanel: Hashable {
    case season(SeasonPickPanel)
    case weekly(WeeklyPickPanel)
}
