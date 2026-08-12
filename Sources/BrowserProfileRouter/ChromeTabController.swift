import Foundation

enum ShortcutAction: Equatable {
    case openCurrentURL
    case focusExistingTab(urlPrefix: String)

    static func forTarget(_ target: BrowserTarget) -> ShortcutAction {
        guard case .chrome = target.kind,
              let urlPrefix = target.existingTabURLPrefix,
              !urlPrefix.isEmpty else {
            return .openCurrentURL
        }
        return .focusExistingTab(urlPrefix: urlPrefix)
    }
}

enum ChromeTabFocusResult: Equatable {
    case focused
    case notFound
    case ambiguous
    case automationFailed

    static func parse(_ output: String) -> ChromeTabFocusResult {
        switch output.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "focused": .focused
        case "notFound": .notFound
        case "ambiguous": .ambiguous
        default: .automationFailed
        }
    }
}

struct ChromeTabController {
    func focusTab(urlPrefix: String) -> ChromeTabFocusResult {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script, urlPrefix]
        process.standardOutput = output
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return .automationFailed
        }

        guard process.terminationStatus == 0 else { return .automationFailed }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        return ChromeTabFocusResult.parse(String(decoding: data, as: UTF8.self))
    }

    private let script = """
    on run argv
        set anchorPrefix to item 1 of argv
        tell application "Google Chrome"
            set matchingWindowIndexes to {}
            set matchingTabIndexes to {}
            repeat with windowIndex from 1 to count of windows
                repeat with tabIndex from 1 to count of tabs of window windowIndex
                    set tabURL to URL of tab tabIndex of window windowIndex
                    if tabURL starts with anchorPrefix then
                        set end of matchingWindowIndexes to windowIndex
                        set end of matchingTabIndexes to tabIndex
                    end if
                end repeat
            end repeat
            if count of matchingWindowIndexes is 0 then return "notFound"
            if count of matchingWindowIndexes is not 1 then return "ambiguous"
            set matchingWindowIndex to item 1 of matchingWindowIndexes
            set active tab index of window matchingWindowIndex to item 1 of matchingTabIndexes
            set index of window matchingWindowIndex to 1
            activate
            return "focused"
        end tell
    end run
    """
}
