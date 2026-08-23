import XCTest
@testable import BrowserProfileRouter

final class LaunchCommandBuilderTests: XCTestCase {
    // Unit: Chrome uses the selected profile directory instead of a last-used profile.
    func testChromeTargetBuildsCommandWithProfileDirectoryAndURL() throws {
        let target = BrowserTarget(
            name: "Work",
            applicationName: "Google Chrome",
            kind: .chrome(profileDirectory: "Profile 2")
        )

        let command = try LaunchCommandBuilder.build(
            target: target,
            urlText: "https://example.com/path?q=work"
        )

        XCTAssertEqual(command.executable, "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")
        XCTAssertEqual(command.arguments, ["--profile-directory=Profile 2", "https://example.com/path?q=work"])
    }

    // Unit: Generic targets remain free of Chrome-specific arguments.
    func testGenericTargetBuildsOpenCommand() throws {
        let target = BrowserTarget(name: "Personal", applicationName: "Safari", kind: .generic)

        let command = try LaunchCommandBuilder.build(target: target, urlText: "https://example.com")

        XCTAssertEqual(command.executable, "/usr/bin/open")
        XCTAssertEqual(command.arguments, ["-a", "Safari", "https://example.com"])
    }

    // Unit: Invalid input is rejected before an executable can be launched.
    func testEmptyChromeProfileIsRejected() {
        let target = BrowserTarget(
            name: "Work",
            applicationName: "Google Chrome",
            kind: .chrome(profileDirectory: "  ")
        )

        XCTAssertThrowsError(try LaunchCommandBuilder.build(target: target, urlText: "https://example.com"))
    }

    // Integration: App-owned configuration persists without touching browser data.
    func testTargetStoreRoundTripsTargetsInItsConfiguredDirectory() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let targets = [
            BrowserTarget(name: "Work", applicationName: "Google Chrome", kind: .chrome(profileDirectory: "Profile 2")),
            BrowserTarget(name: "Personal", applicationName: "Safari", kind: .generic),
        ]
        let store = try TargetStore(directory: directory)

        try store.save(targets)

        XCTAssertEqual(try store.load(), targets)
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("config.yaml").path))
    }

    // Unit: Configuration form values become an explicit Chrome target only when complete.
    func testTargetDraftBuildsChromeTargetFromConfigurationFields() throws {
        let draft = TargetDraft(
            name: "Work",
            applicationName: "Google Chrome",
            usesChromeProfile: true,
            profileDirectory: "Profile 2"
        )

        XCTAssertEqual(
            try draft.buildTarget().kind,
            .chrome(profileDirectory: "Profile 2")
        )
    }

    // Unit: Generic browser configuration still requires a target application.
    func testTargetDraftRejectsEmptyApplicationName() {
        let draft = TargetDraft(
            name: "Personal",
            applicationName: " ",
            usesChromeProfile: false,
            profileDirectory: ""
        )

        XCTAssertThrowsError(try draft.buildTarget())
    }

    // Unit: Editing a target preserves its selection identity while replacing its configuration.
    func testTargetDraftEditsAnExistingTargetWithoutChangingItsID() throws {
        let existing = BrowserTarget(name: "Work", applicationName: "Google Chrome", kind: .chrome(profileDirectory: "Profile 1"))
        var draft = TargetDraft(target: existing)
        draft.profileDirectory = "Profile 2"

        let updated = try draft.buildTarget(id: existing.id)

        XCTAssertEqual(updated.id, existing.id)
        XCTAssertEqual(updated.kind, .chrome(profileDirectory: "Profile 2"))
    }

    // Unit: Chrome profile metadata is read into selectable names without touching Chrome files.
    func testChromeProfileCatalogExtractsDirectoriesAndDisplayNames() throws {
        let localState = try XCTUnwrap("""
        {
          "profile": {
            "info_cache": {
              "Default": { "name": "Personal" },
              "Profile 2": { "name": "Work" }
            }
          }
        }
        """.data(using: .utf8))

        XCTAssertEqual(
            try ChromeProfileCatalog.profiles(from: localState),
            [
                ChromeProfile(directory: "Default", displayName: "Personal"),
                ChromeProfile(directory: "Profile 2", displayName: "Work"),
            ]
        )
    }

    // Unit: Selecting a detected Chrome profile supplies a usable default target name.
    func testTargetDraftPrefillsAnEmptyNameFromTheSelectedProfile() {
        var draft = TargetDraft(
            applicationName: "Google Chrome",
            usesChromeProfile: true,
            profileDirectory: "Profile 2"
        )

        draft.prefillNameIfEmpty(with: "Work")

        XCTAssertEqual(draft.name, "Work")
        XCTAssertTrue(draft.isValid)
    }

    // Integration: UI changes persist as a human-editable YAML configuration.
    func testTargetStoreWritesTargetsToConfigYAML() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try TargetStore(directory: directory)

        try store.save([
            BrowserTarget(name: "Work", applicationName: "Google Chrome", kind: .chrome(profileDirectory: "Profile 2")),
        ])

        let configuration = try String(contentsOf: directory.appendingPathComponent("config.yaml"), encoding: .utf8)
        XCTAssertTrue(configuration.contains("targets:"))
        XCTAssertTrue(configuration.contains("chromeProfile: Profile 2"))
    }

    // Integration: Existing app-private JSON is migrated once instead of being silently ignored.
    func testTargetStoreMigratesLegacyJSONToYAML() throws {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootDirectory) }
        let configurationDirectory = rootDirectory.appendingPathComponent("config", isDirectory: true)
        let legacyURL = rootDirectory.appendingPathComponent("targets.json")
        let targets = [BrowserTarget(name: "Work", applicationName: "Google Chrome", kind: .chrome(profileDirectory: "Profile 2"))]
        try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        try JSONEncoder().encode(targets).write(to: legacyURL)
        let store = try TargetStore(directory: configurationDirectory, legacyFileURLs: [legacyURL])

        XCTAssertEqual(try store.load(), targets)
        XCTAssertTrue(FileManager.default.fileExists(atPath: configurationDirectory.appendingPathComponent("config.yaml").path))
    }

    // Unit: A host rule selects its named browser target, including subdomains.
    func testRoutingRuleMatcherSelectsTargetForMatchingHost() {
        let rules = [RoutingRule(host: "team.example.com", targetName: "Work")]

        XCTAssertEqual(
            RoutingRuleMatcher.match(urlText: "https://mail.team.example.com/messages", rules: rules),
            rules.first
        )
    }

    // Unit: A host rule does not match an unrelated host with a similar suffix.
    func testRoutingRuleMatcherRejectsUnrelatedHost() {
        let rules = [RoutingRule(host: "team.example.com", targetName: "Work")]

        XCTAssertNil(RoutingRuleMatcher.match(urlText: "https://notteam.example.com", rules: rules))
    }

    // Unit: A more specific path rule overrides a matching host-only fallback.
    func testRoutingRuleMatcherPrefersTheLongestMatchingPathPrefix() {
        let hostFallback = RoutingRule(host: "google.com", targetName: "Work")
        let maps = RoutingRule(host: "google.com", pathPrefix: "/maps", targetName: "Personal")
        let place = RoutingRule(host: "google.com", pathPrefix: "/maps/place", targetName: "Work")

        XCTAssertEqual(
            RoutingRuleMatcher.match(
                urlText: "https://www.google.com/maps/place/Nagano",
                rules: [hostFallback, maps, place]
            ),
            place
        )
    }

    // Unit: Path matching respects a path-segment boundary instead of a text prefix.
    func testRoutingRuleMatcherRejectsPartialPathPrefix() {
        let rule = RoutingRule(host: "google.com", pathPrefix: "/maps", targetName: "Personal")

        XCTAssertNil(
            RoutingRuleMatcher.match(
                urlText: "https://www.google.com/mapsfordays",
                rules: [rule]
            )
        )
    }

    // Unit: Equally specific path rules retain YAML declaration order.
    func testRoutingRuleMatcherPreservesRuleOrderForEqualPathPrefixes() {
        let first = RoutingRule(host: "google.com", pathPrefix: "/maps", targetName: "Personal")
        let second = RoutingRule(host: "google.com", pathPrefix: "/maps", targetName: "Work")

        XCTAssertEqual(
            RoutingRuleMatcher.match(
                urlText: "https://www.google.com/maps/search?q=coffee",
                rules: [first, second]
            ),
            first
        )
    }

    // Unit: The UI label includes an optional path condition so the selected rule is inspectable.
    func testRoutingRuleDisplayPatternIncludesPathPrefix() {
        XCTAssertEqual(
            RoutingRule(host: "google.com", pathPrefix: "/maps", targetName: "Personal").displayPattern,
            "google.com/maps"
        )
    }

    // Integration: Hand-written YAML rules survive target edits made in the UI.
    func testTargetStorePreservesRoutingRulesWhenSavingTargets() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try """
        version: 1
        targets: []
        rules:
          - host: team.example.com
            pathPrefix: /messages
            target: Work
        """.write(to: directory.appendingPathComponent("config.yaml"), atomically: true, encoding: .utf8)
        let store = try TargetStore(directory: directory)

        try store.save([BrowserTarget(name: "Work", applicationName: "Google Chrome", kind: .chrome(profileDirectory: "Profile 2"))])

        XCTAssertEqual(
            try store.loadRules(),
            [RoutingRule(host: "team.example.com", pathPrefix: "/messages", targetName: "Work")]
        )
    }

    // Unit: An incoming external URL resolves to the target named by its YAML host rule.
    func testRouteResolverFindsTargetForIncomingURL() {
        let work = BrowserTarget(name: "Work", applicationName: "Google Chrome", kind: .chrome(profileDirectory: "Profile 2"))
        let personal = BrowserTarget(name: "Personal", applicationName: "Safari", kind: .generic)

        XCTAssertEqual(
            RouteResolver.target(urlText: "https://team.example.com/", targets: [personal, work], rules: [RoutingRule(host: "team.example.com", targetName: "Work")]),
            work
        )
    }

    // Unit: An incoming URL without a rule remains in the router for manual profile selection.
    func testRouteResolverDoesNotChooseSelectedTargetWhenIncomingURLHasNoRule() {
        let work = BrowserTarget(name: "Work", applicationName: "Google Chrome", kind: .chrome(profileDirectory: "Profile 2"))
        let personal = BrowserTarget(name: "Personal", applicationName: "Safari", kind: .generic)

        XCTAssertEqual(
            RouteResolver.targetForIncomingURL(
                urlText: "https://unmatched.example.com/",
                targets: [personal, work],
                rules: [],
                selectedTargetID: work.id
            ),
            nil
        )
    }

    // Unit: Keyboard profile navigation follows the displayed order and stays at each boundary.
    func testProfileSelectionMovesInDisplayedOrderAndClampsAtBoundaries() {
        let personal = BrowserTarget(name: "Personal", applicationName: "Safari", kind: .generic)
        let work = BrowserTarget(name: "Work", applicationName: "Google Chrome", kind: .chrome(profileDirectory: "Profile 2"))
        let finance = BrowserTarget(name: "Finance", applicationName: "Google Chrome", kind: .chrome(profileDirectory: "Profile 6"))
        let targets = [personal, work, finance]

        XCTAssertEqual(
            ProfileSelection.targetID(currentTargetID: personal.id, targets: targets, direction: .next),
            work.id
        )
        XCTAssertEqual(
            ProfileSelection.targetID(currentTargetID: finance.id, targets: targets, direction: .next),
            finance.id
        )
        XCTAssertEqual(
            ProfileSelection.targetID(currentTargetID: personal.id, targets: targets, direction: .previous),
            personal.id
        )
        XCTAssertEqual(
            ProfileSelection.targetID(currentTargetID: nil, targets: targets, direction: .previous),
            finance.id
        )
    }

    // Unit: A profile can persist one app-local Command-Option number shortcut.
    func testTargetStoreRoundTripsProfileShortcutNumber() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let target = BrowserTarget(
            name: "Work",
            applicationName: "Google Chrome",
            kind: .chrome(profileDirectory: "Profile 2"),
            shortcutNumber: 3
        )
        let store = try TargetStore(directory: directory)

        try store.save([target])

        XCTAssertEqual(try store.load(), [target])
    }

    // Integration: A local configuration rejects duplicate profile shortcuts so one key maps to one target.
    func testTargetStoreRejectsDuplicateShortcutNumbers() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try TargetStore(directory: directory)
        let first = BrowserTarget(name: "Work", applicationName: "Google Chrome", kind: .chrome(profileDirectory: "Profile 2"), shortcutNumber: 1)
        let second = BrowserTarget(name: "Personal", applicationName: "Safari", kind: .generic, shortcutNumber: 1)

        XCTAssertThrowsError(try store.save([first, second])) { error in
            XCTAssertEqual(error as? TargetStoreError, .duplicateShortcutNumber(1))
        }
    }

    // Unit: A Chrome target persists its local existing-tab URL prefix without publishing it.
    func testTargetStoreRoundTripsExistingTabURLPrefix() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let target = BrowserTarget(
            name: "Work",
            applicationName: "Google Chrome",
            kind: .chrome(profileDirectory: "Profile 2"),
            existingTabURLPrefix: "chrome-extension://example-id/index.html"
        )
        let store = try TargetStore(directory: directory)

        try store.save([target])

        XCTAssertEqual(try store.load(), [target])
    }

    // Unit: Only the controller's bounded success and safe no-op outcomes are accepted.
    func testChromeTabFocusResultParsesBoundedAppleScriptOutcomes() {
        XCTAssertEqual(ChromeTabFocusResult.parse("focused\n"), .focused)
        XCTAssertEqual(ChromeTabFocusResult.parse("notFound\n"), .notFound)
        XCTAssertEqual(ChromeTabFocusResult.parse("ambiguous\n"), .ambiguous)
        XCTAssertEqual(ChromeTabFocusResult.parse("unexpected\n"), .automationFailed)
    }

    // Unit: A shortcut uses an existing Chrome tab only when the target has a local prefix.
    func testShortcutActionFocusesExistingTabForChromeTargetWithPrefix() {
        let target = BrowserTarget(
            name: "Work",
            applicationName: "Google Chrome",
            kind: .chrome(profileDirectory: "Profile 2"),
            existingTabURLPrefix: "chrome-extension://example-id/"
        )

        XCTAssertEqual(
            ShortcutAction.forTarget(target),
            .focusExistingTab(urlPrefix: "chrome-extension://example-id/")
        )
    }

    // Unit: Existing-tab focus accepts only URL prefixes Chrome can expose safely.
    func testTargetDraftRejectsInvalidExistingTabURLPrefix() {
        let draft = TargetDraft(
            name: "Work",
            applicationName: "Google Chrome",
            usesChromeProfile: true,
            profileDirectory: "Profile 2",
            existingTabURLPrefix: "not a URL"
        )

        XCTAssertThrowsError(try draft.buildTarget())
    }

    // Unit: Saving a current URL as a rule starts safely at the host, with the path available as an opt-in refinement.
    func testRuleDraftExtractsHostAndOptionalPathFromCurrentURL() throws {
        var draft = try XCTUnwrap(RuleDraft(urlText: "https://www.google.com/maps/place/Nagano", targetName: "Personal"))

        XCTAssertEqual(draft.host, "www.google.com")
        XCTAssertEqual(draft.pathPrefix, "/maps/place/Nagano")
        XCTAssertFalse(draft.usesPathPrefix)
        XCTAssertEqual(try draft.buildRule(), RoutingRule(host: "www.google.com", targetName: "Personal"))

        draft.usesPathPrefix = true
        XCTAssertEqual(try draft.buildRule(), RoutingRule(host: "www.google.com", pathPrefix: "/maps/place/Nagano", targetName: "Personal"))
    }

    // Integration: UI-owned rule edits preserve configuration order in the same YAML file as targets.
    func testTargetStoreSavesTargetsAndRulesTogether() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try TargetStore(directory: directory)
        let work = BrowserTarget(name: "Work", applicationName: "Google Chrome", kind: .chrome(profileDirectory: "Profile 2"))
        let rules = [
            RoutingRule(host: "first.example.com", targetName: "Work"),
            RoutingRule(host: "second.example.com", targetName: "Work"),
        ]

        try store.save(targets: [work], rules: rules)

        XCTAssertEqual(try store.load(), [work])
        XCTAssertEqual(try store.loadRules(), rules)
    }

    // Integration: An older app refuses an unknown configuration version instead of dropping future fields on save.
    func testTargetStoreRejectsUnsupportedConfigurationVersionWithoutRewritingIt() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let configURL = directory.appendingPathComponent("config.yaml")
        let futureConfiguration = """
        version: 2
        targets: []
        rules: []
        futureField: preserve-me
        """
        try futureConfiguration.write(to: configURL, atomically: true, encoding: .utf8)
        let store = try TargetStore(directory: directory)

        XCTAssertThrowsError(try store.load())
        XCTAssertThrowsError(try store.save([]))
        XCTAssertEqual(try String(contentsOf: configURL, encoding: .utf8), futureConfiguration)
    }

    // Unit: Renaming a profile retains each associated routing decision.
    func testRoutingRuleRetargetsOnlyRulesForTheRenamedProfile() {
        let rules = [
            RoutingRule(host: "work.example.com", targetName: "Work"),
            RoutingRule(host: "personal.example.com", targetName: "Personal"),
        ]

        XCTAssertEqual(
            RoutingRule.retargeting(rules, from: "Work", to: "Company"),
            [
                RoutingRule(host: "work.example.com", targetName: "Company"),
                RoutingRule(host: "personal.example.com", targetName: "Personal"),
            ]
        )
    }

    // Unit: Removing a profile also removes only that profile's rules, leaving no dangling YAML references.
    func testRoutingRuleRemovesRulesForDeletedProfile() {
        let rules = [
            RoutingRule(host: "work.example.com", targetName: "Work"),
            RoutingRule(host: "personal.example.com", targetName: "Personal"),
        ]

        XCTAssertEqual(
            RoutingRule.removing(rules, forTargetNames: ["Work"]),
            [RoutingRule(host: "personal.example.com", targetName: "Personal")]
        )
    }
}
