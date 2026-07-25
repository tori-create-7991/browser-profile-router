import Foundation
import Yams

enum TargetStoreError: Error, Equatable {
    case unsupportedConfigurationVersion(Int)
}

final class TargetStore {
    private let fileURL: URL
    private let legacyFileURLs: [URL]

    init(directory: URL, legacyFileURLs: [URL] = []) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("config.yaml")
        self.legacyFileURLs = legacyFileURLs
    }

    static func defaultDirectory() -> URL {
        let environment = ProcessInfo.processInfo.environment
        let baseDirectory: URL
        if let configuredPath = environment["XDG_CONFIG_HOME"], !configuredPath.isEmpty {
            baseDirectory = URL(fileURLWithPath: configuredPath, isDirectory: true)
        } else {
            baseDirectory = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".config", isDirectory: true)
        }
        return baseDirectory.appendingPathComponent("browser-profile-router", isDirectory: true)
    }

    static func defaultStore() throws -> TargetStore {
        let legacyDirectory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ).appendingPathComponent("BrowserProfileRouter", isDirectory: true)
        return try TargetStore(
            directory: defaultDirectory(),
            legacyFileURLs: [legacyDirectory.appendingPathComponent("targets.json")]
        )
    }

    func load() throws -> [BrowserTarget] {
        try loadConfiguration().targets.map(\.browserTarget)
    }

    func loadRules() throws -> [RoutingRule] {
        try loadConfiguration().rules
    }

    func save(_ targets: [BrowserTarget]) throws {
        let currentConfiguration = try loadConfiguration()
        try save(targets: targets, rules: currentConfiguration.rules)
    }

    func save(targets: [BrowserTarget], rules: [RoutingRule]) throws {
        let currentConfiguration = try loadConfiguration()
        try write(Configuration(
            version: currentConfiguration.version,
            targets: targets.map(Configuration.Target.init),
            rules: rules
        ))
    }

    private func loadConfiguration() throws -> Configuration {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let contents = try String(contentsOf: fileURL, encoding: .utf8)
            let configuration = try YAMLDecoder().decode(Configuration.self, from: contents)
            guard configuration.version == 1 else {
                throw TargetStoreError.unsupportedConfigurationVersion(configuration.version)
            }
            return configuration
        }
        for legacyFileURL in legacyFileURLs where FileManager.default.fileExists(atPath: legacyFileURL.path) {
            guard let data = try? Data(contentsOf: legacyFileURL),
                  let targets = try? JSONDecoder().decode([BrowserTarget].self, from: data) else {
                continue
            }
            let configuration = Configuration(version: 1, targets: targets.map(Configuration.Target.init), rules: [])
            try write(configuration)
            return configuration
        }
        return Configuration(version: 1, targets: [], rules: [])
    }

    private func write(_ configuration: Configuration) throws {
        let contents = try YAMLEncoder().encode(configuration)
        try contents.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    private struct Configuration: Codable {
        let version: Int
        let targets: [Target]
        let rules: [RoutingRule]

        init(version: Int, targets: [Target], rules: [RoutingRule]) {
            self.version = version
            self.targets = targets
            self.rules = rules
        }

        enum CodingKeys: String, CodingKey {
            case version
            case targets
            case rules
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
            targets = try container.decodeIfPresent([Target].self, forKey: .targets) ?? []
            rules = try container.decodeIfPresent([RoutingRule].self, forKey: .rules) ?? []
        }

        struct Target: Codable {
            let id: UUID
            let name: String
            let application: String
            let chromeProfile: String?

            init(_ target: BrowserTarget) {
                id = target.id
                name = target.name
                application = target.applicationName
                switch target.kind {
                case .generic:
                    chromeProfile = nil
                case .chrome(let profileDirectory):
                    chromeProfile = profileDirectory
                }
            }

            var browserTarget: BrowserTarget {
                BrowserTarget(
                    id: id,
                    name: name,
                    applicationName: application,
                    kind: chromeProfile.map { .chrome(profileDirectory: $0) } ?? .generic
                )
            }
        }
    }
}
