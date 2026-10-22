// Renders the Toki app icon (時 = "time") without alpha channel
// (App Store Connect drops icons with alpha silently). Run on macOS:
//   swift tools/make-icon.swift Toki/Assets.xcassets/AppIcon.appiconset/AppIcon.png [variant]
import AppKit
import CoreText

let size = 1024
let s = Double(size)
let output = URL(fileURLWithPath: CommandLine.arguments[1])
let variant = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "sunset"
let rgb = CGColorSpaceCreateDeviceRGB()
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: rgb, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!

func color(_ hex: UInt32, _ alpha: Double = 1) -> CGColor {
    CGColor(red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255, alpha: alpha)
}

func gradient(_ colors: [CGColor], from: CGPoint, to: CGPoint) {
    let g = CGGradient(colorsSpace: rgb, colors: colors as CFArray, locations: nil)!
    context.drawLinearGradient(g, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

/// Brush-like open circle (ensō): a thick arc that thins out towards its end.
func enso(center: CGPoint, radius: Double, color: CGColor, width: Double, start: Double, sweep: Double) {
    let steps = 240
    context.setFillColor(color)
    for i in 0...steps {
        let t = Double(i) / Double(steps)
        let angle = start + sweep * t
        let w = width * (1 - 0.75 * pow(t, 2.2))
        let p = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
        context.fillEllipse(in: CGRect(x: p.x - w / 2, y: p.y - w / 2, width: w, height: w))
    }
}

func glyph(_ text: String, font name: String, size fontSize: Double, color: CGColor, center: CGPoint) {
    let font = CTFontCreateWithName(name as CFString, fontSize, nil)
    let attributed = NSAttributedString(string: text, attributes: [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
    ])
    let line = CTLineCreateWithAttributedString(attributed)
    let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
    context.textPosition = CGPoint(x: center.x - bounds.midX, y: center.y - bounds.midY)
    CTLineDraw(line, context)
}

let center = CGPoint(x: s / 2, y: s / 2)
switch variant {
case "night":
    // Night sky with a red sun circle behind a white kanji.
    gradient([color(0x1B1F4A), color(0x07080F)], from: CGPoint(x: 0, y: s), to: CGPoint(x: s, y: 0))
    context.setFillColor(color(0xE8453C))
    context.fillEllipse(in: CGRect(x: center.x - 330, y: center.y - 330, width: 660, height: 660))
    glyph("時", font: "HiraginoSans-W8", size: 520, color: color(0xFFFFFF), center: center)
case "ink":
    // Paper white, black ensō, red kanji like a hanko stamp.
    gradient([color(0xF7F1E3), color(0xE9DFC8)], from: CGPoint(x: 0, y: s), to: CGPoint(x: s, y: 0))
    enso(center: center, radius: 360, color: color(0x15151A), width: 92, start: .pi * 0.62, sweep: -.pi * 1.85)
    glyph("時", font: "HiraginoMincho-ProN-W6", size: 470, color: color(0xC8322B), center: center)
default:
    // "sunset": anime dusk gradient, white brush ensō as clock face, white kanji, small green +1 sun.
    gradient([color(0xFF8A5B), color(0xB2457A), color(0x2A1F5C)], from: CGPoint(x: s * 0.2, y: s), to: CGPoint(x: s * 0.8, y: 0))
    enso(center: center, radius: 365, color: color(0xFFFFFF, 0.95), width: 70, start: .pi * 0.58, sweep: -.pi * 1.82)
    glyph("時", font: "HiraginoSans-W7", size: 440, color: color(0xFFFFFF), center: CGPoint(x: center.x, y: center.y - 6))
    let dot = CGRect(x: s * 0.70, y: s * 0.70, width: s * 0.13, height: s * 0.13)
    context.setFillColor(color(0x5AC777))
    context.fillEllipse(in: dot)
}

let rep = NSBitmapImageRep(cgImage: context.makeImage()!)
try rep.representation(using: .png, properties: [:])!.write(to: output)
