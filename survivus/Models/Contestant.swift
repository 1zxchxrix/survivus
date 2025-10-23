import Foundation

struct Contestant: Identifiable, Hashable, Codable {
    let id: String
    var name: String
    var tribe: String?
    var avatarAssetName: String?
    var avatarURL: URL?

    init(
        id: String,
        name: String,
        tribe: String? = nil,
        avatarAssetName: String? = nil,
        avatarURL: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.tribe = tribe
        self.avatarAssetName = avatarAssetName

        if let explicitURL = avatarURL {
            self.avatarURL = explicitURL
        } else if let asset = avatarAssetName?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !asset.isEmpty {
            self.avatarURL = StoragePaths.contestantAvatarURL(for: asset)
        } else {
            self.avatarURL = nil
        }
    }
}

extension Contestant {
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case tribe
        case avatarAssetName
        case avatarURL
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        let name = try container.decode(String.self, forKey: .name)
        let tribe = try container.decodeIfPresent(String.self, forKey: .tribe)
        let avatarAssetName = try container.decodeIfPresent(String.self, forKey: .avatarAssetName)
        let avatarURL = try container.decodeIfPresent(URL.self, forKey: .avatarURL)

        self.init(
            id: id,
            name: name,
            tribe: tribe,
            avatarAssetName: avatarAssetName,
            avatarURL: avatarURL
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(tribe, forKey: .tribe)
        try container.encodeIfPresent(avatarAssetName, forKey: .avatarAssetName)
        try container.encodeIfPresent(avatarURL, forKey: .avatarURL)
    }
}
