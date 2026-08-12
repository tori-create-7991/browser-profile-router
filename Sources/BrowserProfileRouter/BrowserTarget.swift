import Foundation

struct BrowserTarget: Codable, Equatable, Identifiable {
    enum Kind: Codable, Equatable {
        case generic
        case chrome(profileDirectory: String)
    }

    let id: UUID
    var name: String
    var applicationName: String
    var kind: Kind
    var shortcutNumber: Int?
    var existingTabURLPrefix: String?

    init(
        id: UUID = UUID(),
        name: String,
        applicationName: String,
        kind: Kind,
        shortcutNumber: Int? = nil,
        existingTabURLPrefix: String? = nil
    ) {
        self.id = id
        self.name = name
        self.applicationName = applicationName
        self.kind = kind
        self.shortcutNumber = shortcutNumber
        self.existingTabURLPrefix = existingTabURLPrefix
    }
}

struct LaunchCommand: Equatable {
    let executable: String
    let arguments: [String]
}

enum LaunchCommandError: Error {
    case invalidURL
    case emptyProfileDirectory
}

enum TargetDraftError: Error {
    case emptyName
    case emptyApplicationName
    case emptyProfileDirectory
    case invalidExistingTabURLPrefix
}

struct TargetDraft {
    var name: String = ""
    var applicationName: String = ""
    var usesChromeProfile: Bool = false
    var profileDirectory: String = ""
    var shortcutNumber: Int?
    var existingTabURLPrefix: String = ""

    init(
        name: String = "",
        applicationName: String = "",
        usesChromeProfile: Bool = false,
        profileDirectory: String = "",
        shortcutNumber: Int? = nil,
        existingTabURLPrefix: String = ""
    ) {
        self.name = name
        self.applicationName = applicationName
        self.usesChromeProfile = usesChromeProfile
        self.profileDirectory = profileDirectory
        self.shortcutNumber = shortcutNumber
        self.existingTabURLPrefix = existingTabURLPrefix
    }

    init(target: BrowserTarget) {
        name = target.name
        applicationName = target.applicationName
        switch target.kind {
        case .generic:
            usesChromeProfile = false
            profileDirectory = ""
        case .chrome(let directory):
            usesChromeProfile = true
            profileDirectory = directory
        }
        shortcutNumber = target.shortcutNumber
        existingTabURLPrefix = target.existingTabURLPrefix ?? ""
    }

    var isValid: Bool {
        let hasName = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasApplicationName = !applicationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasProfileDirectory = !usesChromeProfile || !profileDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasName && hasApplicationName && hasProfileDirectory
    }

    mutating func prefillNameIfEmpty(with suggestedName: String) {
        guard name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        name = suggestedName
    }

    func buildTarget(id: UUID = UUID()) throws -> BrowserTarget {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw TargetDraftError.emptyName }
        let trimmedApplicationName = applicationName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedApplicationName.isEmpty else { throw TargetDraftError.emptyApplicationName }
        if usesChromeProfile {
            let trimmedProfileDirectory = profileDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedProfileDirectory.isEmpty else { throw TargetDraftError.emptyProfileDirectory }
            let existingTabURLPrefix = try normalizedExistingTabURLPrefix()
            return BrowserTarget(
                id: id,
                name: trimmedName,
                applicationName: trimmedApplicationName,
                kind: .chrome(profileDirectory: trimmedProfileDirectory),
                shortcutNumber: shortcutNumber,
                existingTabURLPrefix: existingTabURLPrefix
            )
        }
        return BrowserTarget(id: id, name: trimmedName, applicationName: trimmedApplicationName, kind: .generic, shortcutNumber: shortcutNumber)
    }

    private func normalizedExistingTabURLPrefix() throws -> String? {
        let trimmedPrefix = existingTabURLPrefix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrefix.isEmpty else { return nil }
        guard let url = URL(string: trimmedPrefix),
              let scheme = url.scheme?.lowercased(),
              ["http", "https", "chrome-extension"].contains(scheme),
              url.host != nil else {
            throw TargetDraftError.invalidExistingTabURLPrefix
        }
        return trimmedPrefix
    }
}

enum LaunchCommandBuilder {
    static func build(target: BrowserTarget, urlText: String) throws -> LaunchCommand {
        guard let url = URL(string: urlText),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil else {
            throw LaunchCommandError.invalidURL
        }

        switch target.kind {
        case .generic:
            return LaunchCommand(
                executable: "/usr/bin/open",
                arguments: ["-a", target.applicationName, url.absoluteString]
            )
        case .chrome(let profileDirectory):
            let trimmedProfileDirectory = profileDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedProfileDirectory.isEmpty else {
                throw LaunchCommandError.emptyProfileDirectory
            }
            return LaunchCommand(
                executable: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
                arguments: ["--profile-directory=\(trimmedProfileDirectory)", url.absoluteString]
            )
        }
    }
}
