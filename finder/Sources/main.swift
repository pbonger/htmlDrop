import Foundation
import Darwin

// MARK: - CLI notification + icon helpers

func workflowIconPath() -> String? {
    let bin = URL(fileURLWithPath: CommandLine.arguments[0]).standardized.resolvingSymlinksInPath()
    let icon = bin
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Resources/icon.icns")
    return FileManager.default.fileExists(atPath: icon.path) ? icon.path : nil
}

func terminalNotifierPath() -> String? {
    if let icon = workflowIconPath() {
        let bundled = URL(fileURLWithPath: icon)
            .deletingLastPathComponent()
            .appendingPathComponent("terminal-notifier.app/Contents/MacOS/terminal-notifier")
        if FileManager.default.fileExists(atPath: bundled.path) { return bundled.path }
    }
    for path in ["/opt/homebrew/bin/terminal-notifier", "/usr/local/bin/terminal-notifier"] {
        if FileManager.default.fileExists(atPath: path) { return path }
    }
    return nil
}

func notify(_ title: String, _ message: String, openUrl: String? = nil) {
    if let tn = terminalNotifierPath(), let url = openUrl {
        var args = ["-title", title, "-message", message, "-open", url]
        if let icon = workflowIconPath() { args += ["-appIcon", icon] }
        run(tn, args: args)
    } else {
        run("/usr/bin/osascript", args: ["-e",
            "display notification \"\(message.esc)\" with title \"\(title.esc)\""])
    }
}

// MARK: - CLI share dialog

func osascript(_ script: String) -> (Int32, String) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    p.arguments = ["-e", script]
    let out = Pipe(); let err = Pipe()
    p.standardOutput = out; p.standardError = err
    try? p.run(); p.waitUntilExit()
    return (p.terminationStatus, String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "")
}

// Returns nil = cancelled, "" = share publicly, non-empty = encrypt with this password
func confirmShare() -> String? {
    let iconClause = workflowIconPath().map { "with icon (POSIX file \"\($0.esc)\")" } ?? "with icon note"

    let (status, output) = osascript(
        "display dialog \"Share this page on Netlify?\" " +
        "buttons {\"Cancel\", \"Add password\u{2026}\", \"Share\"} default button \"Share\" \(iconClause)"
    )
    guard status == 0 else { return nil }
    if output.contains("Share") { return "" }

    let (status2, out2) = osascript(
        "display dialog \"Enter a password to protect this page:\" " +
        "default answer \"\" with hidden answer buttons {\"Cancel\", \"Share\"} default button \"Share\" \(iconClause)"
    )
    guard status2 == 0, let range = out2.range(of: "text returned:") else { return nil }
    let pw = String(out2[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
    return pw.isEmpty ? nil : pw
}

// MARK: - Entry point

let args = CommandLine.arguments
guard args.count > 1 else { fputs("Usage: netlify-share <file.html>\n", stderr); exit(1) }

let filePath = args[1]
guard filePath.lowercased().hasSuffix(".html") else {
    notify("Netlify Share", "Only HTML files are supported")
    exit(0)
}

guard let password = confirmShare() else { exit(0) }

do {
    notify("Netlify Share", password.isEmpty ? "Uploading…" : "Encrypting and uploading…")
    let html  = try String(contentsOfFile: filePath, encoding: .utf8)
    let token: String
    if let t = tokenGet() { token = t } else { token = try login() }
    let content = password.isEmpty ? wrapHtml(html) : (try encryptHtml(html, password: password))
    let zipURL  = try makeZip(content)
    let url     = try netlifyUpload(zipURL: zipURL, token: token)
    copyToClipboard(url)
    notify("Shared on Netlify",
           password.isEmpty ? "URL copied to clipboard" : "URL copied to clipboard (password protected)",
           openUrl: url)
    print(url)
} catch {
    notify("Netlify Share Failed", error.localizedDescription)
    fputs("Error: \(error)\n", stderr)
    exit(1)
}
