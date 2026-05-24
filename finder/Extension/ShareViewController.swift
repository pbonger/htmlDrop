import AppKit
import Foundation
import os.log

private let log = OSLog(subsystem: "com.pbonger.html-drop-app.extension", category: "ShareVC")

@objc(ShareViewController)
class ShareViewController: NSViewController {

    override func loadView() {
        view = NSView(frame: .zero)
    }

    override func beginRequest(with context: NSExtensionContext) {
        os_log("beginRequest: items=%d", log: log, context.inputItems.count)

        guard let item = context.inputItems.first as? NSExtensionItem else {
            os_log("beginRequest: no NSExtensionItem", log: log)
            DispatchQueue.main.async { self.showError("No extension item", context: context) }
            return
        }

        let attachments = item.attachments ?? []
        os_log("beginRequest: attachments=%d", log: log, attachments.count)

        guard let provider = attachments.first else {
            os_log("beginRequest: no provider", log: log)
            DispatchQueue.main.async { self.showError("No attachment", context: context) }
            return
        }

        let types = provider.registeredTypeIdentifiers
        os_log("beginRequest: types=%{public}@", log: log, types.joined(separator: ", "))

        // Use loadFileRepresentation for public.html — it creates a sandboxed temp copy
        // the extension can actually read. public.file-url gives the original path which
        // is outside the extension sandbox and can't be read directly.
        if types.contains(where: { $0 == "public.html" || $0.hasPrefix("public.html") }) {
            loadViaFileRepresentation(provider: provider, context: context)
        } else if types.contains("public.file-url") {
            loadViaFileURL(provider: provider, context: context)
        } else {
            os_log("beginRequest: no usable type", log: log)
            DispatchQueue.main.async { self.showError("No usable type: \(types.joined(separator: ", "))", context: context) }
        }
    }

    private func loadViaFileRepresentation(provider: NSItemProvider, context: NSExtensionContext) {
        os_log("loadViaFileRepresentation", log: log)

        // macOS prefixes the temp file name with the UTType description ("HTML text.html"),
        // so we can't trust lastPathComponent or suggestedName for the display name.
        // Instead: get the real filename from public.file-url, then load content via
        // loadFileRepresentation which creates a sandboxed temp copy the extension can read.
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
            let rawURL: URL?
            if let u = item as? URL { rawURL = u }
            else if let d = item as? Data { rawURL = URL(dataRepresentation: d, relativeTo: nil) }
            else { rawURL = nil }

            let filename = rawURL
                .flatMap { ($0 as NSURL).filePathURL ?? $0 }
                .map { $0.lastPathComponent } ?? "file.html"
            os_log("loadViaFileRepresentation: resolved filename=%{public}@", log: log, filename)

            provider.loadFileRepresentation(forTypeIdentifier: "public.html") { url, error in
                guard let fileURL = url,
                      let html = try? String(contentsOf: fileURL, encoding: .utf8) else {
                    let msg = error?.localizedDescription ?? "Cannot read file"
                    DispatchQueue.main.async { self.showError(msg, context: context) }
                    return
                }
                DispatchQueue.main.async {
                    self.showShareDialog(filename: filename, html: html, context: context)
                }
            }
        }
    }

    private func loadViaFileURL(provider: NSItemProvider, context: NSExtensionContext) {
        os_log("loadViaFileURL", log: log)
        // Strong capture: this headless VC has no UI so the extension host releases it
        // immediately — weak self would be nil by the time the async block runs.
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, error in
            os_log("loadItem callback: item=%{public}@ error=%{public}@",
                   log: log, String(describing: item), error?.localizedDescription ?? "nil")
            let url: URL?
            if let u = item as? URL { url = u }
            else if let d = item as? Data { url = URL(dataRepresentation: d, relativeTo: nil) }
            else { url = nil }

            guard let rawURL = url else {
                let msg = error?.localizedDescription ?? "Cannot get URL"
                DispatchQueue.main.async { self.showError(msg, context: context) }
                return
            }
            // Finder can return a file reference URL (file:///.file/id=…) instead of a
            // path URL — resolve it to a real path before reading.
            let fileURL = (rawURL as NSURL).filePathURL ?? rawURL
            os_log("loadItem resolved: %{public}@", log: log, fileURL.path)

            _ = fileURL.startAccessingSecurityScopedResource()
            let html = try? String(contentsOf: fileURL, encoding: .utf8)
            fileURL.stopAccessingSecurityScopedResource()

            guard let html = html else {
                DispatchQueue.main.async { self.showError("Cannot read: \(fileURL.path)", context: context) }
                return
            }
            let filename = fileURL.lastPathComponent
            DispatchQueue.main.async {
                self.showShareDialog(filename: filename, html: html, context: context)
            }
        }
    }

    // MARK: - Dialogs

    private func showShareDialog(filename: String, html: String, context: NSExtensionContext) {
        os_log("showShareDialog: %{public}@", log: log, filename)
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Share on HTML Drop"
        alert.informativeText = filename
        alert.icon = bundleIcon()
        alert.addButton(withTitle: "Share")
        alert.addButton(withTitle: "Add Password…")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:  upload(html: html, password: "", context: context)
        case .alertSecondButtonReturn: showPasswordDialog(filename: filename, html: html, context: context)
        default:                       context.cancelRequest(withError: Fail("Cancelled"))
        }
    }

    private func showPasswordDialog(filename: String, html: String, context: NSExtensionContext) {
        NSApp.activate(ignoringOtherApps: true)
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
        case .alertFirstButtonReturn: upload(html: html, password: field.stringValue, context: context)
        default:                      context.cancelRequest(withError: Fail("Cancelled"))
        }
    }

    // MARK: - Upload

    private func upload(html: String, password: String, context: NSExtensionContext) {
        DispatchQueue.global().async {
            do {
                let service = UploadService.named(currentProvider) ?? .freekit
                let siteUrl = try htmlDropUpload(html, password: password, service: service)
                copyToClipboard(siteUrl)
                DispatchQueue.main.async { self.showSuccess(siteUrl, context: context) }
            } catch {
                DispatchQueue.main.async { self.showError(error.localizedDescription, context: context) }
            }
        }
    }

    private func showSuccess(_ url: String, context: NSExtensionContext) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Shared on HTML Drop"
        alert.informativeText = "URL copied to clipboard:\n\(url)"
        alert.icon = bundleIcon()
        alert.addButton(withTitle: "Open in Browser")
        alert.addButton(withTitle: "OK")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: url)!)
        }
        context.completeRequest(returningItems: nil, completionHandler: nil)
    }

    private func showError(_ message: String, context: NSExtensionContext) {
        os_log("showError: %{public}@", log: log, message)
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "HTML Drop Error"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.icon = bundleIcon()
        alert.addButton(withTitle: "OK")
        alert.runModal()
        context.cancelRequest(withError: Fail(message))
    }

    private func bundleIcon() -> NSImage? {
        Bundle.main.image(forResource: "AppIcon")
    }
}
