import Foundation
import CoreGraphics
import AppKit

// Script to render the official macOS AppIcon for Duplix
let sizes: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]

let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("DuplixIconset_\(UUID().uuidString)")
let iconsetURL = tempDir.appendingPathComponent("AppIcon.iconset")
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

func drawIcon(size: Int) -> Data {
    let s = CGFloat(size)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!

    let rect = CGRect(x: 0, y: 0, width: s, height: s)

    // Base Squircle Background
    let squircleInset = s * 0.1
    let squircleRect = rect.insetBy(dx: squircleInset, dy: squircleInset)
    let cornerRadius = s * 0.22
    let squirclePath = CGPath(roundedRect: squircleRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

    // Background Gradient (Deep Indigo to Electric Purple)
    let colors = [
        CGColor(red: 0.22, green: 0.18, blue: 0.88, alpha: 1.0),
        CGColor(red: 0.58, green: 0.12, blue: 0.95, alpha: 1.0)
    ] as CFArray
    let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0])!

    ctx.saveGState()
    ctx.addPath(squirclePath)
    ctx.clip()
    ctx.drawLinearGradient(gradient, start: CGPoint(x: s * 0.2, y: s * 0.8), end: CGPoint(x: s * 0.8, y: s * 0.2), options: [])
    ctx.restoreGState()

    // Inner subtle glow border
    ctx.saveGState()
    ctx.addPath(squirclePath)
    ctx.setLineWidth(s * 0.015)
    ctx.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.35))
    ctx.strokePath()
    ctx.restoreGState()

    // Primary & Secondary Duplicate Card Symbols
    // 1. Back Card (Offset to top-right)
    let cardW = s * 0.38
    let cardH = s * 0.44
    let cardCorner = s * 0.08

    let backCardRect = CGRect(x: s * 0.42, y: s * 0.34, width: cardW, height: cardH)
    let backCardPath = CGPath(roundedRect: backCardRect, cornerWidth: cardCorner, cornerHeight: cardCorner, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.02), blur: s * 0.04, color: CGColor(gray: 0, alpha: 0.3))
    ctx.addPath(backCardPath)
    ctx.setFillColor(CGColor(red: 0.0, green: 0.85, blue: 0.75, alpha: 0.85)) // Vibrant Cyan/Teal
    ctx.fillPath()
    ctx.restoreGState()

    // 2. Front Card (Main - bottom-left)
    let frontCardRect = CGRect(x: s * 0.24, y: s * 0.22, width: cardW, height: cardH)
    let frontCardPath = CGPath(roundedRect: frontCardRect, cornerWidth: cardCorner, cornerHeight: cardCorner, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.03), blur: s * 0.05, color: CGColor(gray: 0, alpha: 0.4))
    ctx.addPath(frontCardPath)
    ctx.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.95)) // Crisp White Card
    ctx.fillPath()
    ctx.restoreGState()

    // Duplicate badge icon ("D" / double layer in front card)
    let innerIconRect = frontCardRect.insetBy(dx: cardW * 0.22, dy: cardH * 0.22)
    let innerIconPath = CGPath(roundedRect: innerIconRect, cornerWidth: cardCorner * 0.6, cornerHeight: cardCorner * 0.6, transform: nil)
    ctx.saveGState()
    ctx.addPath(innerIconPath)
    ctx.setFillColor(CGColor(red: 0.35, green: 0.22, blue: 0.90, alpha: 0.9))
    ctx.fillPath()
    ctx.restoreGState()

    let image = ctx.makeImage()!
    let rep = NSBitmapImageRep(cgImage: image)
    return rep.representation(using: .png, properties: [:])!
}

for (size, filename) in sizes {
    let data = drawIcon(size: size)
    let fileURL = iconsetURL.appendingPathComponent(filename)
    try data.write(to: fileURL)
}

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.icns"
let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
proc.arguments = ["-c", "icns", iconsetURL.path, "-o", outputPath]
try proc.run()
proc.waitUntilExit()

try? FileManager.default.removeItem(at: tempDir)
print("Successfully generated: \(outputPath)")
