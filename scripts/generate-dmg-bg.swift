#!/usr/bin/swift
import AppKit

let W: CGFloat = 560
let H: CGFloat = 300
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/dmg-bg.png"

let image = NSImage(size: NSSize(width: W, height: H))
image.lockFocus()

// ── Background ────────────────────────────────────────────────────────────────
NSColor(red: 0.11, green: 0.11, blue: 0.14, alpha: 1).setFill()
NSBezierPath.fill(NSRect(x: 0, y: 0, width: W, height: H))

// Subtle top fade
let topGrad = NSGradient(
    colors: [NSColor(white: 1, alpha: 0.03), NSColor(white: 1, alpha: 0)],
    atLocations: [0, 1],
    colorSpace: .genericGray
)!
topGrad.draw(in: NSRect(x: 0, y: H - 60, width: W, height: 60), angle: 270)

// ── Left panel — instructions ─────────────────────────────────────────────────
let panelX: CGFloat = 28
var y: CGFloat = H - 44

func attr(_ text: String, size: CGFloat, bold: Bool = false, color: NSColor = .white) -> NSAttributedString {
    NSAttributedString(string: text, attributes: [
        .font: bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size, weight: .regular),
        .foregroundColor: color
    ])
}

// Title
attr("Install HTML Drop", size: 17, bold: true).draw(at: NSPoint(x: panelX, y: y))
y -= 6

// Divider
NSColor(white: 1, alpha: 0.12).setStroke()
let div = NSBezierPath()
div.move(to: NSPoint(x: panelX, y: y))
div.line(to: NSPoint(x: 260, y: y))
div.stroke()
y -= 22

let accent = NSColor(red: 0.38, green: 0.65, blue: 1.0, alpha: 1)
let muted  = NSColor(white: 0.65, alpha: 1)
let steps: [(String, String)] = [
    ("1", "Double-click  HTML Drop.pkg"),
    ("2", "Click  OK  on the warning dialog"),
    ("3", "Open  System Settings → Privacy & Security"),
    ("4", "Scroll down, click  Open Anyway"),
    ("5", "Follow the installer steps"),
]

for (num, text) in steps {
    // Circle badge
    let circle = NSBezierPath(ovalIn: NSRect(x: panelX, y: y - 1, width: 18, height: 18))
    accent.withAlphaComponent(0.18).setFill()
    circle.fill()
    accent.setStroke()
    circle.lineWidth = 1
    circle.stroke()
    attr(num, size: 10, bold: true, color: accent).draw(at: NSPoint(x: panelX + (num == "1" ? 5.5 : 5), y: y + 2))

    attr(text, size: 12.5, color: NSColor(white: 0.88, alpha: 1)).draw(at: NSPoint(x: panelX + 26, y: y + 2))
    y -= 30
}

y -= 4
attr("The installer sets up the Finder Share menu", size: 10.5, color: muted).draw(at: NSPoint(x: panelX, y: y))
y -= 16
attr("and the WebStorm plugin automatically.", size: 10.5, color: muted).draw(at: NSPoint(x: panelX, y: y))

// ── Right panel — icon placeholder area ───────────────────────────────────────
// Arrow pointing right from instructions to icon
let arrowY: CGFloat = H / 2 - 10
let arrowColor = NSColor(white: 1, alpha: 0.1)
arrowColor.setStroke()
let arrow = NSBezierPath()
arrow.move(to:    NSPoint(x: 268, y: arrowY))
arrow.line(to:    NSPoint(x: 300, y: arrowY))
arrow.line(to:    NSPoint(x: 292, y: arrowY - 7))
arrow.move(to:    NSPoint(x: 300, y: arrowY))
arrow.line(to:    NSPoint(x: 292, y: arrowY + 7))
arrow.lineWidth = 1.5
arrow.stroke()

// "double-click" label under icon area
attr("double-click to install", size: 10, color: NSColor(white: 1, alpha: 0.25))
    .draw(at: NSPoint(x: 358, y: 32))

image.unlockFocus()

let tiff = image.tiffRepresentation!
let rep  = NSBitmapImageRep(data: tiff)!
let png  = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: outPath))
print("✓ Background written to \(outPath)")
