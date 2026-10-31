// Renders the app icon (1024x1024 PNG). Usage: swift make_icon.swift out.png
import AppKit

let size = 1024.0
let out = CommandLine.arguments[1]
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

let inset = size * 0.1
let rect = NSRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
let path = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.225, yRadius: rect.width * 0.225)
NSGradient(colors: [
    NSColor(calibratedRed: 0.45, green: 0.55, blue: 1.0, alpha: 1),
    NSColor(calibratedRed: 0.30, green: 0.20, blue: 0.85, alpha: 1),
])!.draw(in: path, angle: -90)

let config = NSImage.SymbolConfiguration(pointSize: size * 0.40, weight: .semibold)
    .applying(.init(paletteColors: [.white]))
if let symbol = NSImage(systemSymbolName: "list.clipboard.fill", accessibilityDescription: nil)?
    .withSymbolConfiguration(config) {
    let s = symbol.size
    symbol.draw(in: NSRect(x: (size - s.width) / 2, y: (size - s.height) / 2,
                           width: s.width, height: s.height))
}
image.unlockFocus()

let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
