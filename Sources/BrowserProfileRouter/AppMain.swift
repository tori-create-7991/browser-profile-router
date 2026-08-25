import SwiftUI

enum ProfileSelection {
    enum Direction {
        case next
        case previous
    }

    static func targetID(
        currentTargetID: UUID?,
        targets: [BrowserTarget],
        direction: Direction
    ) -> UUID? {
        guard !targets.isEmpty else { return nil }
        guard let currentTargetID,
              let currentIndex = targets.firstIndex(where: { $0.id == currentTargetID }) else {
            return direction == .next ? targets.first?.id : targets.last?.id
        }

        switch direction {
        case .next:
            return targets[min(currentIndex + 1, targets.count - 1)].id
        case .previous:
            return targets[max(currentIndex - 1, 0)].id
        }
    }
}

@main
struct BrowserProfileRouterApp: App {
    var body: some Scene {
        WindowGroup {
            RouterView()
        }
    }
}

@MainActor
final class RouterViewModel: ObservableObject {
    @Published var urlText = ""
    @Published private(set) var targets: [BrowserTarget] = []
    @Published private(set) var matchedRule: RoutingRule?
    @Published private(set) var rules: [RoutingRule] = []
    @Published var selectedTargetID: UUID?
    @Published var errorMessage: String?

    private let store: TargetStore?

    var isConfigurationAvailable: Bool {
        store != nil
    }

    init(
        store: TargetStore? = nil,
        defaultStore: () throws -> TargetStore = { try TargetStore.defaultStore() }
    ) {
        do {
            let resolvedStore = try store ?? defaultStore()
            let loadedTargets = try resolvedStore.load()
            let loadedRules = try resolvedStore.loadRules()
            self.store = resolvedStore
            targets = loadedTargets
            rules = loadedRules
            selectedTargetID = loadedTargets.first?.id
        } catch {
            self.store = nil
            errorMessage = "Could not initialize configuration: \(error.localizedDescription) Check \(TargetStore.defaultDirectory().path) and restart the app."
        }
    }

    var selectedTarget: BrowserTarget? {
        targets.first { $0.id == selectedTargetID }
    }

    var commandPreview: String? {
        guard let selectedTarget else { return nil }
        guard let command = try? LaunchCommandBuilder.build(target: selectedTarget, urlText: urlText) else { return nil }
        return ([command.executable] + command.arguments).map(shellQuoted).joined(separator: " ")
    }

    func add(_ target: BrowserTarget) {
        targets.append(target)
        selectedTargetID = target.id
        persist()
    }

    func replace(_ target: BrowserTarget) {
        guard let index = targets.firstIndex(where: { $0.id == target.id }) else { return }
        let previousTarget = targets[index]
        targets[index] = target
        rules = RoutingRule.retargeting(rules, from: previousTarget.name, to: target.name)
        persist()
    }

    func delete(at offsets: IndexSet) {
        let targetNames = offsets.map { targets[$0].name }
        targets.remove(atOffsets: offsets)
        rules = RoutingRule.removing(rules, forTargetNames: targetNames)
        if selectedTarget == nil { selectedTargetID = targets.first?.id }
        persist()
    }

    func rules(for target: BrowserTarget) -> [RoutingRule] {
        rules.filter { $0.targetName == target.name }
    }

    func add(_ rule: RoutingRule) {
        rules.append(rule)
        persist()
    }

    func replace(_ rule: RoutingRule, replacing previousRule: RoutingRule) {
        guard let index = rules.firstIndex(of: previousRule) else { return }
        rules[index] = rule
        persist()
    }

    func delete(_ rule: RoutingRule) {
        guard let index = rules.firstIndex(of: rule) else { return }
        rules.remove(at: index)
        persist()
    }

    func launch() {
        guard let selectedTarget else {
            errorMessage = "Choose a browser target first."
            return
        }
        do {
            let command = try LaunchCommandBuilder.build(target: selectedTarget, urlText: urlText)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: command.executable)
            process.arguments = command.arguments
            try process.run()
        } catch {
            errorMessage = "The URL or target configuration is invalid: \(error.localizedDescription)"
        }
    }

    func moveSelection(_ direction: ProfileSelection.Direction) {
        selectedTargetID = ProfileSelection.targetID(
            currentTargetID: selectedTargetID,
            targets: targets,
            direction: direction
        )
    }

    func performShortcut(for target: BrowserTarget) {
        selectedTargetID = target.id
        switch ShortcutAction.forTarget(target) {
        case .openCurrentURL:
            launch()
        case .focusExistingTab(let urlPrefix):
            switch ChromeTabController().focusTab(urlPrefix: urlPrefix) {
            case .focused:
                break
            case .notFound:
                errorMessage = "No open Chrome tab matches this profile's existing-tab URL."
            case .ambiguous:
                errorMessage = "More than one open Chrome tab matches this profile's existing-tab URL."
            case .automationFailed:
                errorMessage = "Could not focus the Chrome tab. Allow BrowserProfileRouter to control Google Chrome if macOS asks."
            }
        }
    }

    func applyMatchingRule() {
        guard let rule = RoutingRuleMatcher.match(urlText: urlText, rules: rules),
              let target = RouteResolver.target(urlText: urlText, targets: targets, rules: rules) else {
            matchedRule = nil
            return
        }
        matchedRule = rule
        selectedTargetID = target.id
    }

    @discardableResult
    func openIncomingURL(_ url: URL) -> Bool {
        urlText = url.absoluteString
        applyMatchingRule()
        guard matchedRule != nil else { return true }
        launch()
        return false
    }

    private func persist() {
        guard let store else {
            errorMessage = "Could not save targets: configuration is unavailable."
            return
        }
        do {
            try store.save(targets: targets, rules: rules)
        } catch {
            errorMessage = "Could not save targets: \(error.localizedDescription)"
        }
    }
}

private struct RouterView: View {
    @StateObject private var model = RouterViewModel()
    @FocusState private var isProfileListFocused: Bool
    @State private var isPresentingEditor = false
    @State private var editingTarget: BrowserTarget?
    @State private var isPresentingRuleEditor = false
    @State private var editingRule: RoutingRule?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Browser Profile Router").font(.title2)
            if !model.isConfigurationAvailable {
                Text("Configuration is unavailable. Fix the configuration directory permissions, then restart the app.")
                    .foregroundStyle(.red)
            }
            ForEach(model.targets.filter { $0.shortcutNumber != nil }) { target in
                Button("Open \(target.name)") {
                    model.performShortcut(for: target)
                }
                .keyboardShortcut(
                    KeyEquivalent(Character(String(target.shortcutNumber!))),
                    modifiers: [.command, .option]
                )
                .hidden()
            }
            Text("Paste a URL, then choose where to open it. This app does not register as your default browser.")
                .foregroundStyle(.secondary)
            TextField("https://example.com", text: $model.urlText)
                .textFieldStyle(.roundedBorder)
                .onChange(of: model.urlText) { _, _ in
                    model.applyMatchingRule()
                }
            Picker("Browser target", selection: $model.selectedTargetID) {
                Text("Choose a target").tag(UUID?.none)
                ForEach(model.targets) { target in
                    Text(target.name).tag(Optional(target.id))
                }
            }
            if let matchedRule = model.matchedRule {
                Text("Rule matched: \(matchedRule.displayPattern) → \(matchedRule.targetName)")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Button("Add Target") {
                    editingTarget = nil
                    isPresentingEditor = true
                }
                Button("Edit Target") {
                    editingTarget = model.selectedTarget
                    isPresentingEditor = true
                }
                .disabled(model.selectedTarget == nil)
                Button("Delete Target", role: .destructive) {
                    guard let selectedTargetID = model.selectedTargetID,
                          let index = model.targets.firstIndex(where: { $0.id == selectedTargetID }) else { return }
                    model.delete(at: IndexSet(integer: index))
                }
                .disabled(model.selectedTarget == nil)
                Button("Open URL with Selected Profile") { model.launch() }
                    .disabled(model.commandPreview == nil)
                Button("Add Rule for This URL") {
                    editingRule = nil
                    isPresentingRuleEditor = true
                }
                .disabled(model.selectedTarget == nil || RuleDraft(urlText: model.urlText, targetName: model.selectedTarget?.name ?? "") == nil)
            }
            GroupBox("Launch preview") {
                Text(model.commandPreview ?? "Enter a valid http(s) URL and choose a target.")
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading) {
                    Text("Profiles").font(.headline)
                    List(selection: $model.selectedTargetID) {
                        ForEach(model.targets) { target in
                            VStack(alignment: .leading) {
                                Text(target.name)
                                Text(targetDescription(target)).foregroundStyle(.secondary)
                            }
                            .tag(Optional(target.id))
                        }
                        .onDelete(perform: model.delete)
                    }
                    .focused($isProfileListFocused)
                    .onKeyPress(.upArrow) {
                        model.moveSelection(.previous)
                        return .handled
                    }
                    .onKeyPress(.downArrow) {
                        model.moveSelection(.next)
                        return .handled
                    }
                    .onKeyPress(.return) {
                        guard model.commandPreview != nil else { return .ignored }
                        model.launch()
                        return .handled
                    }
                    .frame(minWidth: 220, minHeight: 180)
                    Text("For an unmatched URL, use ↑/↓ to select and Return to open.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading) {
                    Text(model.selectedTarget.map { "Rules for \($0.name)" } ?? "Rules")
                        .font(.headline)
                    if let target = model.selectedTarget {
                        List {
                            ForEach(model.rules(for: target)) { rule in
                                HStack {
                                    Text(rule.displayPattern)
                                    Spacer()
                                    Button("Edit") {
                                        editingRule = rule
                                        isPresentingRuleEditor = true
                                    }
                                    Button("Delete", role: .destructive) {
                                        model.delete(rule)
                                    }
                                }
                            }
                        }
                        .frame(minWidth: 300, minHeight: 180)
                    } else {
                        Text("Choose a profile to manage its rules.").foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .frame(minWidth: 560, minHeight: 420)
        .disabled(!model.isConfigurationAvailable)
        .alert("Browser Profile Router", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
        .sheet(isPresented: $isPresentingEditor) {
            TargetEditor(target: editingTarget) { target in
                if editingTarget == nil {
                    model.add(target)
                } else {
                    model.replace(target)
                }
                isPresentingEditor = false
            }
        }
        .sheet(isPresented: $isPresentingRuleEditor) {
            if let target = model.selectedTarget {
                RuleEditor(
                    rule: editingRule,
                    targetName: target.name,
                    suggestedURL: model.urlText
                ) { rule in
                    if let editingRule {
                        model.replace(rule, replacing: editingRule)
                    } else {
                        model.add(rule)
                    }
                    isPresentingRuleEditor = false
                }
            }
        }
        .onOpenURL { url in
            if model.openIncomingURL(url) {
                isProfileListFocused = true
            }
        }
    }
}

private struct RuleEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: RuleDraft
    @State private var errorMessage: String?
    private let existingRule: RoutingRule?
    let onSave: (RoutingRule) -> Void

    init(rule: RoutingRule?, targetName: String, suggestedURL: String, onSave: @escaping (RoutingRule) -> Void) {
        existingRule = rule
        self.onSave = onSave
        _draft = State(initialValue: rule.map { RuleDraft(rule: $0, targetName: targetName) }
            ?? RuleDraft(urlText: suggestedURL, targetName: targetName)
            ?? RuleDraft(targetName: targetName))
    }

    var body: some View {
        Form {
            Text("Profile: \(draft.targetName)").foregroundStyle(.secondary)
            TextField("Host", text: $draft.host)
            Toggle("Use a path prefix", isOn: $draft.usesPathPrefix)
            if draft.usesPathPrefix {
                TextField("Path prefix (for example: /maps)", text: $draft.pathPrefix)
            }
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }
            HStack {
                Button("Cancel") { dismiss() }
                Button(existingRule == nil ? "Add Rule" : "Save Rule") {
                    do {
                        onSave(try draft.buildRule())
                    } catch {
                        errorMessage = "Enter a valid host and, if used, a path prefix beginning with /."
                    }
                }
                .disabled(!draft.isValid)
            }
        }
        .padding()
        .frame(width: 460)
    }
}

private struct TargetEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: TargetDraft
    @State private var errorMessage: String?
    @State private var chromeProfiles: [ChromeProfile] = []
    private let existingTarget: BrowserTarget?
    let onSave: (BrowserTarget) -> Void

    init(target: BrowserTarget?, onSave: @escaping (BrowserTarget) -> Void) {
        existingTarget = target
        self.onSave = onSave
        _draft = State(initialValue: target.map(TargetDraft.init(target:)) ?? TargetDraft())
    }

    var body: some View {
        Form {
            TextField("Name", text: $draft.name)
            Picker("Application", selection: $draft.applicationName) {
                Text("Choose an app").tag("")
                if !draft.applicationName.isEmpty && !BrowserApplicationCatalog.names.contains(draft.applicationName) {
                    Text(draft.applicationName).tag(draft.applicationName)
                }
                ForEach(BrowserApplicationCatalog.names, id: \.self) { name in
                    Text(name).tag(name)
                }
            }
            Toggle("Use a Chrome profile", isOn: $draft.usesChromeProfile)
            Picker("Shortcut", selection: $draft.shortcutNumber) {
                Text("None").tag(Int?.none)
                ForEach(1...9, id: \.self) { number in
                    Text("⌘⌥\(number)").tag(Optional(number))
                }
            }
            if draft.usesChromeProfile {
                if chromeProfiles.isEmpty {
                    TextField("Chrome profile directory (for example: Profile 2)", text: $draft.profileDirectory)
                    Text("No Chrome profiles were found; enter the directory from chrome://version.")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Chrome profile", selection: $draft.profileDirectory) {
                        Text("Choose a Chrome profile").tag("")
                        ForEach(chromeProfiles) { profile in
                            Text("\(profile.displayName) (\(profile.directory))").tag(profile.directory)
                        }
                    }
                }
                TextField("Existing tab URL prefix (optional)", text: $draft.existingTabURLPrefix)
                Text("With a shortcut, this focuses exactly one matching open Chrome tab without creating a tab.")
                    .foregroundStyle(.secondary)
            }
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }
            HStack {
                Button("Cancel") { dismiss() }
                Button("Save") {
                    do {
                        onSave(try draft.buildTarget(id: existingTarget?.id ?? UUID()))
                    } catch {
                        errorMessage = "Complete the name, application, and Chrome profile fields."
                    }
                }
                .disabled(!draft.isValid)
            }
        }
        .padding()
        .frame(width: 460)
        .onAppear {
            chromeProfiles = ChromeProfileCatalog.profiles()
            prefillNameFromSelectedChromeProfile()
        }
        .onChange(of: draft.usesChromeProfile) { _, usesChromeProfile in
            if usesChromeProfile {
                draft.applicationName = "Google Chrome"
            }
        }
        .onChange(of: draft.profileDirectory) { _, _ in
            prefillNameFromSelectedChromeProfile()
        }
    }

    private func prefillNameFromSelectedChromeProfile() {
        guard let profile = chromeProfiles.first(where: { $0.directory == draft.profileDirectory }) else { return }
        draft.prefillNameIfEmpty(with: profile.displayName)
    }
}

private enum BrowserApplicationCatalog {
    static let names = ["Google Chrome", "Safari", "Firefox", "Microsoft Edge", "Arc"]
        .filter { FileManager.default.fileExists(atPath: "/Applications/\($0).app") }
}

private func targetDescription(_ target: BrowserTarget) -> String {
    switch target.kind {
    case .generic:
        return "Generic: \(target.applicationName)"
    case .chrome(let profileDirectory):
        return "Chrome profile: \(profileDirectory)"
    }
}

private func shellQuoted(_ value: String) -> String {
    "'\(value.replacingOccurrences(of: "'", with: "'\\\"'\\\"'"))'"
}
