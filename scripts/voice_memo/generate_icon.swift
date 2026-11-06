import Foundation
import CoreGraphics
import AppKit

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

let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("VoiceMemoIconset_\(UUID().uuidString)")
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

    // Duplix Voice Gradient (Deep Violet to Vivid Coral/Rose)
    let colors = [
        CGColor(red: 0.15, green: 0.10, blue: 0.55, alpha: 1.0), // Deep Indigo
        CGColor(red: 0.85, green: 0.20, blue: 0.45, alpha: 1.0)  // Electric Rose
    ] as CFArray
    let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0])!

    ctx.saveGState()
    ctx.addPath(squirclePath)
    ctx.clip()
    ctx.drawLinearGradient(gradient, start: CGPoint(x: s * 0.2, y: s * 0.85), end: CGPoint(x: s * 0.8, y: s * 0.15), options: [])
    ctx.restoreGState()

    // Inner subtle glow border
    ctx.saveGState()
    ctx.addPath(squirclePath)
    ctx.setLineWidth(s * 0.015)
    ctx.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.35))
    ctx.strokePath()
    ctx.restoreGState()

    // Central Microphone Icon (CoreGraphics paths)
    let cx = s * 0.5
    let cy = s * 0.54
    
    // 1. Microphone Capsule (Body)
    let capW = s * 0.18
    let capH = s * 0.32
    let capRadius = capW * 0.5
    let capRect = CGRect(x: cx - (capW / 2), y: cy - (capH / 2) + (s * 0.02), width: capW, height: capH)
    let capPath = CGPath(roundedRect: capRect, cornerWidth: capRadius, cornerHeight: capRadius, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.02), blur: s * 0.04, color: CGColor(gray: 0, alpha: 0.4))
    ctx.addPath(capPath)
    ctx.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.98))
    ctx.fillPath()
    ctx.restoreGState()

    // 2. Microphone Cradle (Arc)
    let cradleRadius = capW * 0.85
    let cradleCenter = CGPoint(x: cx, y: capRect.midY - (s * 0.02))
    let cradlePath = CGMutablePath()
    cradlePath.addArc(center: cradleCenter, radius: cradleRadius, startAngle: .pi, endAngle: 0, clockwise: true)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.015), blur: s * 0.03, color: CGColor(gray: 0, alpha: 0.35))
    ctx.addPath(cradlePath)
    ctx.setLineWidth(s * 0.03)
    ctx.setLineCap(.round)
    ctx.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.95))
    ctx.strokePath()
    ctx.restoreGState()

    // 3. Stem
    let stemPath = CGMutablePath()
    let stemTopY = cradleCenter.y - cradleRadius
    let stemBottomY = stemTopY - (s * 0.10)
    stemPath.move(to: CGPoint(x: cx, y: stemTopY))
    stemPath.addLine(to: CGPoint(x: cx, y: stemBottomY))

    ctx.saveGState()
    ctx.addPath(stemPath)
    ctx.setLineWidth(s * 0.03)
    ctx.setLineCap(.round)
    ctx.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.95))
    ctx.strokePath()
    ctx.restoreGState()

    // 4. Base Horizontal Bar
    let baseW = s * 0.16
    let basePath = CGMutablePath()
    basePath.move(to: CGPoint(x: cx - (baseW / 2), y: stemBottomY))
    basePath.addLine(to: CGPoint(x: cx + (baseW / 2), y: stemBottomY))

    ctx.saveGState()
    ctx.addPath(basePath)
    ctx.setLineWidth(s * 0.03)
    ctx.setLineCap(.round)
    ctx.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.95))
    ctx.strokePath()
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

// Also save 512x512 PNG for previews
let pngData = drawIcon(size: 512)
let pngURL = URL(fileURLWithPath: outputPath).deletingPathExtension().appendingPathExtension("png")
try pngData.write(to: pngURL)

try? FileManager.default.removeItem(at: tempDir)
print("Successfully generated: \(outputPath) and \(pngURL.path)")

