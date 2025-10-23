import Foundation

struct Contestant: Identifiable, Hashable, Codable {
    let id: String
    var name: String
    var tribe: String?
    var avatarURL: URL?
}
