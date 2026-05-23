import AppKit
import Foundation

@objc(ShareViewController)
class ShareViewController: NSViewController {

    override func loadView() {
        view = NSView(frame: .zero)
    }

    override func beginRequest(with context: NSExtensionContext) {
        guard let item     = context.inputItems.first as? NSExtensionItem,
              let provider = item.attachments?.first else {
            context.cancelRequest(withError: Fail("No attachment"))
            return
        }

        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { [weak self] item, _ in
            let url: URL?
            if let u = item as? URL { url = u }
            else if let d = item as? Data { url = URL(dataRepresentation: d, relativeTo: nil) }
            else { url = nil }

            guard let fileURL = url, fileURL.pathExtension.lowercased() == "html" else {
                context.cancelRequest(withError: Fail("Not an HTML file"))
                return
            }
            DispatchQueue.main.async { self?.showShareDialog(for: fileURL, context: context) }
        }
    }

    // MARK: - Dialogs

    private func showShareDialog(for url: URL, context: NSExtensionContext) {
        let alert = NSAlert()
        alert.messageText = "Share on Netlify"
        alert.informativeText = url.lastPathComponent
        alert.icon = bundleIcon()
        alert.addButton(withTitle: "Share")
        alert.addButton(withTitle: "Add Password…")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:  upload(url: url, password: "",   context: context)
        case .alertSecondButtonReturn: showPasswordDialog(for: url, context: context)
        default:                       context.cancelRequest(withError: Fail("Cancelled"))
        }
    }

    private func showPasswordDialog(for url: URL, context: NSExtensionContext) {
        let alert = NSAlert()
        alert.messageText = "Password protect this page"
        alert.icon = bundleIcon()
        alert.addButton(withTitle: "Share")
        alert.addButton(withTitle: "Cancel")

        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        field.placeholderString = "Password"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        switch alert.runModal() {
        case .alertFirstButtonReturn: upload(url: url, password: field.stringValue, context: context)
        default:                      context.cancelRequest(withError: Fail("Cancelled"))
        }
    }

    // MARK: - Upload

    private func upload(url: URL, password: String, context: NSExtensionContext) {
        DispatchQueue.global().async {
            do {
                let html    = try String(contentsOf: url, encoding: .utf8)
                let token   = try tokenGet() ?? login()
                let content = password.isEmpty ? wrapHtml(html) : (try encryptHtml(html, password: password))
                let zipURL  = try makeZip(content)
                let siteUrl = try netlifyUpload(zipURL: zipURL, token: token)
                copyToClipboard(siteUrl)
                self.notify("Shared on Netlify",
                            password.isEmpty ? "URL copied to clipboard" : "URL copied (password protected)",
                            openUrl: siteUrl)
                context.completeRequest(returningItems: nil, completionHandler: nil)
            } catch {
                self.notify("Netlify Share Failed", error.localizedDescription)
                context.cancelRequest(withError: error)
            }
        }
    }

    // MARK: - Notification

    private func notify(_ title: String, _ message: String, openUrl: String? = nil) {
        let tnPath = Bundle.main.url(
            forResource: "terminal-notifier",
            withExtension: nil,
            subdirectory: "terminal-notifier.app/Contents/MacOS"
        )?.path
        if let tn = tnPath, let url = openUrl, FileManager.default.fileExists(atPath: tn) {
            var args = ["-title", title, "-message", message, "-open", url]
            if let icon = Bundle.main.path(forResource: "AppIcon", ofType: "icns") {
                args += ["-appIcon", icon]
            }
            run(tn, args: args)
        } else {
            run("/usr/bin/osascript", args: ["-e",
                "display notification \"\(message.esc)\" with title \"\(title.esc)\""])
        }
    }

    private func bundleIcon() -> NSImage? {
        Bundle.main.image(forResource: "AppIcon")
    }
}
