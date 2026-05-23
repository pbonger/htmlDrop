import AppKit

// Minimal host app — just a container for the Share Extension.
// Opens briefly to register the extension, then quits.
let app = NSApplication.shared

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ n: Notification) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
        p.arguments = ["-e", "use", "-i", "com.pbonger.html-drop-app.extension"]
        try? p.run()
        p.waitUntilExit()
        NSApp.terminate(nil)
    }
}

let delegate = AppDelegate()
app.delegate = delegate
app.run()
