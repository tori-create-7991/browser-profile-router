import Foundation

struct ChromeProfile: Equatable, Identifiable {
    let directory: String
    let displayName: String

    var id: String { directory }
}

enum ChromeProfileCatalog {
    private static let localStateURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Google/Chrome/Local State")

    static func profiles() -> [ChromeProfile] {
        guard let data = try? Data(contentsOf: localStateURL) else { return [] }
        return (try? profiles(from: data)) ?? []
    }

    static func profiles(from data: Data) throws -> [ChromeProfile] {
        let localState = try JSONDecoder().decode(LocalState.self, from: data)
        return localState.profile.infoCache
            .map { ChromeProfile(directory: $0.key, displayName: $0.value.name ?? $0.key) }
            .sorted { $0.directory < $1.directory }
    }

    private struct LocalState: Decodable {
        let profile: Profile
    }

    private struct Profile: Decodable {
        let infoCache: [String: ProfileInfo]

        enum CodingKeys: String, CodingKey {
            case infoCache = "info_cache"
        }
    }

    private struct ProfileInfo: Decodable {
        let name: String?
    }
}
