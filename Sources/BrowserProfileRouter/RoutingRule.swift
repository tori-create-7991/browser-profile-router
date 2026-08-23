import Foundation

struct RoutingRule: Codable, Equatable, Identifiable {
    let host: String
    let pathPrefix: String?
    let targetName: String

    init(host: String, pathPrefix: String? = nil, targetName: String) {
        self.host = host
        self.pathPrefix = pathPrefix
        self.targetName = targetName
    }

    var id: String { "\(host)|\(pathPrefix ?? "")|\(targetName)" }

    var displayPattern: String { "\(host)\(pathPrefix ?? "")" }

    enum CodingKeys: String, CodingKey {
        case host
        case pathPrefix
        case targetName = "target"
    }

    static func retargeting(_ rules: [RoutingRule], from oldTargetName: String, to newTargetName: String) -> [RoutingRule] {
        rules.map { rule in
            guard rule.targetName == oldTargetName else { return rule }
            return RoutingRule(host: rule.host, pathPrefix: rule.pathPrefix, targetName: newTargetName)
        }
    }

    static func removing(_ rules: [RoutingRule], forTargetNames targetNames: [String]) -> [RoutingRule] {
        rules.filter { !targetNames.contains($0.targetName) }
    }
}

enum RuleDraftError: Error {
    case invalidHost
    case invalidPathPrefix
    case emptyTargetName
}

struct RuleDraft {
    var host: String
    var pathPrefix: String
    var usesPathPrefix: Bool
    let targetName: String

    init(host: String = "", pathPrefix: String = "", usesPathPrefix: Bool = false, targetName: String) {
        self.host = host
        self.pathPrefix = pathPrefix
        self.usesPathPrefix = usesPathPrefix
        self.targetName = targetName
    }

    init?(urlText: String, targetName: String) {
        guard let url = URL(string: urlText),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = url.host else {
            return nil
        }
        self.init(host: host, pathPrefix: url.path, usesPathPrefix: false, targetName: targetName)
    }

    init(rule: RoutingRule, targetName: String) {
        self.init(
            host: rule.host,
            pathPrefix: rule.pathPrefix ?? "",
            usesPathPrefix: rule.pathPrefix != nil,
            targetName: targetName
        )
    }

    var isValid: Bool {
        (try? buildRule()) != nil
    }

    func buildRule() throws -> RoutingRule {
        let normalizedHost = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedHost.isEmpty,
              URL(string: "https://\(normalizedHost)")?.host != nil else {
            throw RuleDraftError.invalidHost
        }
        let normalizedTargetName = targetName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTargetName.isEmpty else { throw RuleDraftError.emptyTargetName }
        guard usesPathPrefix else {
            return RoutingRule(host: normalizedHost, targetName: normalizedTargetName)
        }
        let normalizedPathPrefix = pathPrefix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedPathPrefix.hasPrefix("/") else { throw RuleDraftError.invalidPathPrefix }
        return RoutingRule(host: normalizedHost, pathPrefix: normalizedPathPrefix, targetName: normalizedTargetName)
    }
}

enum RoutingRuleMatcher {
    static func match(urlText: String, rules: [RoutingRule]) -> RoutingRule? {
        guard let url = URL(string: urlText), let host = url.host?.lowercased() else {
            return nil
        }
        var bestMatch: (rule: RoutingRule, pathLength: Int)?
        for rule in rules {
            let ruleHost = rule.host.lowercased()
            guard host == ruleHost || host.hasSuffix(".\(ruleHost)") else {
                continue
            }
            guard let pathPrefix = normalizedPathPrefix(rule.pathPrefix), pathMatches(url.path, pathPrefix) else {
                if rule.pathPrefix != nil {
                    continue
                }
                if bestMatch == nil {
                    bestMatch = (rule, 0)
                }
                continue
            }
            if bestMatch == nil || pathPrefix.count > bestMatch!.pathLength {
                bestMatch = (rule, pathPrefix.count)
            }
        }
        return bestMatch?.rule
    }

    private static func normalizedPathPrefix(_ pathPrefix: String?) -> String? {
        guard let pathPrefix, pathPrefix.hasPrefix("/") else {
            return nil
        }
        guard pathPrefix.count > 1 else {
            return pathPrefix
        }
        return pathPrefix.hasSuffix("/") ? String(pathPrefix.dropLast()) : pathPrefix
    }

    private static func pathMatches(_ path: String, _ pathPrefix: String) -> Bool {
        pathPrefix == "/" || path == pathPrefix || path.hasPrefix("\(pathPrefix)/")
    }
}

enum RouteResolver {
    static func target(urlText: String, targets: [BrowserTarget], rules: [RoutingRule]) -> BrowserTarget? {
        guard let rule = RoutingRuleMatcher.match(urlText: urlText, rules: rules) else {
            return nil
        }
        return targets.first { $0.name == rule.targetName }
    }

    static func targetForIncomingURL(
        urlText: String,
        targets: [BrowserTarget],
        rules: [RoutingRule],
        selectedTargetID: UUID?
    ) -> BrowserTarget? {
        target(urlText: urlText, targets: targets, rules: rules)
    }
}
