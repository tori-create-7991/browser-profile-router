import Foundation
import Yams

enum TargetStoreError: Error, Equatable {
    case unsupportedConfigurationVersion(Int)
    case invalidShortcutNumber(Int)
    case duplicateShortcutNumber(Int)
    case duplicateTargetName(String)
    case existingTabURLPrefixRequiresChrome
    case invalidExistingTabURLPrefix
}

final class TargetStore {
    private let fileURL: URL
    private let legacyFileURLs: [URL]

    init(directory: URL, legacyFileURLs: [URL] = []) throws {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
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
            let decodedConfiguration = try YAMLDecoder().decode(Configuration.self, from: contents)
            guard decodedConfiguration.version == 1 else {
                throw TargetStoreError.unsupportedConfigurationVersion(decodedConfiguration.version)
            }
            let (configuration, migratedDuplicateNames) = migratingDuplicateTargetNames(in: decodedConfiguration)
            try validate(configuration)
            if migratedDuplicateNames {
                try write(configuration)
            }
            return configuration
        }
        for legacyFileURL in legacyFileURLs where FileManager.default.fileExists(atPath: legacyFileURL.path) {
            guard let data = try? Data(contentsOf: legacyFileURL),
                  let targets = try? JSONDecoder().decode([BrowserTarget].self, from: data) else {
                continue
            }
            let (configuration, _) = migratingDuplicateTargetNames(in: Configuration(
                version: 1,
                targets: targets.map(Configuration.Target.init),
                rules: []
            ))
            try write(configuration)
            return configuration
        }
        return Configuration(version: 1, targets: [], rules: [])
    }

    private func write(_ configuration: Configuration) throws {
        try validate(configuration)
        let contents = try YAMLEncoder().encode(configuration)
        try contents.write(to: fileURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }

    private func validate(_ configuration: Configuration) throws {
        var targetNames = Set<String>()
        var assignedShortcuts = Set<Int>()
        for target in configuration.targets.map(\.browserTarget) {
            guard targetNames.insert(target.name).inserted else {
                throw TargetStoreError.duplicateTargetName(target.name)
            }
            if let shortcut = target.shortcutNumber {
                guard (1...9).contains(shortcut) else {
                    throw TargetStoreError.invalidShortcutNumber(shortcut)
                }
                guard assignedShortcuts.insert(shortcut).inserted else {
                    throw TargetStoreError.duplicateShortcutNumber(shortcut)
                }
            }

            guard let urlPrefix = target.existingTabURLPrefix, !urlPrefix.isEmpty else { continue }
            guard case .chrome = target.kind else {
                throw TargetStoreError.existingTabURLPrefixRequiresChrome
            }
            guard let url = URL(string: urlPrefix),
                  let scheme = url.scheme?.lowercased(),
                  ["http", "https", "chrome-extension"].contains(scheme),
                  url.host != nil else {
                throw TargetStoreError.invalidExistingTabURLPrefix
            }
        }
    }

    private func migratingDuplicateTargetNames(in configuration: Configuration) -> (Configuration, Bool) {
        let existingNames = Set(configuration.targets.map(\.name))
        var usedNames = Set<String>()
        var occurrences = [String: Int]()
        var migrated = false
        let targets = configuration.targets.map { target -> Configuration.Target in
            let occurrence = (occurrences[target.name] ?? 0) + 1
            occurrences[target.name] = occurrence
            guard occurrence > 1 else {
                usedNames.insert(target.name)
                return target
            }

            var suffix = occurrence
            var migratedName = "\(target.name) (\(suffix))"
            while existingNames.contains(migratedName) || usedNames.contains(migratedName) {
                suffix += 1
                migratedName = "\(target.name) (\(suffix))"
            }
            usedNames.insert(migratedName)
            migrated = true
            return Configuration.Target(BrowserTarget(
                id: target.id,
                name: migratedName,
                applicationName: target.application,
                kind: target.chromeProfile.map { .chrome(profileDirectory: $0) } ?? .generic,
                shortcutNumber: target.shortcut,
                existingTabURLPrefix: target.existingTabURLPrefix
            ))
        }
        return (Configuration(version: configuration.version, targets: targets, rules: configuration.rules), migrated)
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
            let shortcut: Int?
            let existingTabURLPrefix: String?

            init(_ target: BrowserTarget) {
                id = target.id
                name = target.name
                application = target.applicationName
                shortcut = target.shortcutNumber
                existingTabURLPrefix = target.existingTabURLPrefix
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
                    kind: chromeProfile.map { .chrome(profileDirectory: $0) } ?? .generic,
                    shortcutNumber: shortcut,
                    existingTabURLPrefix: existingTabURLPrefix
                )
            }
        }
    }
}
