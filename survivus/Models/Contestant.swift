import Foundation

struct Contestant: Identifiable, Hashable, Codable {
    let id: String
    var name: String
    var tribe: String?
    var avatarAssetName: String?
    private var explicitAvatarURL: URL?

    var avatarURL: URL? {
        get {
            if let explicitAvatarURL {
                return explicitAvatarURL
            }

            guard let asset = avatarAssetName?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !asset.isEmpty else {
                return nil
            }

            return StoragePaths.contestantAvatarURL(for: asset)
        }
        set {
            explicitAvatarURL = newValue
        }
    }

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
        self.explicitAvatarURL = avatarURL
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


