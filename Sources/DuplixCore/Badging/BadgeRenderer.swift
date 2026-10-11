import Foundation
import CoreGraphics
import AppKit

public struct BadgeRenderer: Sendable {
    public init() {}

    public enum RenderError: LocalizedError, Sendable {
        case failedToLoadImage(URL)
        case failedToCreateContext(Int, Int)
        case failedToExportPNG

        public var errorDescription: String? {
            switch self {
            case .failedToLoadImage(let url):
                return "Failed to load image from \(url.path)"
            case .failedToCreateContext(let w, let h):
                return "Failed to create CoreGraphics context for \(w)x\(h)"
            case .failedToExportPNG:
                return "Failed to generate PNG image data"
            }
        }
    }

    /// Reads a PNG file, applies the badge, and saves the modified PNG back to the destination URL.
    public func applyBadge(
        toImageAt sourceURL: URL,
        destinationURL: URL,
        config: BadgeConfig
    ) throws {
        let data = try Data(contentsOf: sourceURL)
        guard let imageRep = NSBitmapImageRep(data: data),
              let cgImage = imageRep.cgImage else {
            throw RenderError.failedToLoadImage(sourceURL)
        }

        let width = cgImage.width
        let height = cgImage.height

        let badgedData = try renderBadge(on: cgImage, width: width, height: height, config: config)
        try badgedData.write(to: destinationURL, options: .atomic)
    }

    /// CoreGraphics drawing pipeline for a single icon resolution.
    public func renderBadge(
        on cgImage: CGImage,
        width: Int,
        height: Int,
        config: BadgeConfig
    ) throws -> Data {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw RenderError.failedToCreateContext(width, height)
        }

        // 1. Draw base icon
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // 2. Compute badge geometry
        let badgeDiameter = CGFloat(width) * config.sizeRatio
        let margin = CGFloat(width) * 0.04

        let badgeX: CGFloat
        let badgeY: CGFloat

        switch config.position {
        case .bottomRight:
            badgeX = CGFloat(width) - badgeDiameter - margin
            badgeY = margin
        case .bottomLeft:
            badgeX = margin
            badgeY = margin
        case .topRight:
            badgeX = CGFloat(width) - badgeDiameter - margin
            badgeY = CGFloat(height) - badgeDiameter - margin
        case .topLeft:
            badgeX = margin
            badgeY = CGFloat(height) - badgeDiameter - margin
        }

        let badgeRect = CGRect(x: badgeX, y: badgeY, width: badgeDiameter, height: badgeDiameter)

        // 3. Draw soft drop shadow
        if config.showShadow && badgeDiameter >= 16 {
            context.saveGState()
            let shadowBlur = badgeDiameter * 0.16
            let shadowColor = CGColor(gray: 0.0, alpha: 0.45)
            context.setShadow(
                offset: CGSize(width: 0, height: -shadowBlur * 0.4),
                blur: shadowBlur,
                color: shadowColor
            )
            context.setFillColor(config.color.cgColor)
            context.fillEllipse(in: badgeRect)
            context.restoreGState()
        }

        // 4. Fill badge circle
        context.setFillColor(config.color.cgColor)
        context.fillEllipse(in: badgeRect)

        // 5. Draw crisp white border
        if config.showBorder {
            let borderWidth = max(1.0, badgeDiameter * 0.08)
            context.setStrokeColor(CGColor(gray: 1.0, alpha: 0.95))
            context.setLineWidth(borderWidth)
            let strokeRect = badgeRect.insetBy(dx: borderWidth / 2, dy: borderWidth / 2)
            context.strokeEllipse(in: strokeRect)
        }

        // 6. Draw centered text / number
        if let text = config.text, !text.isEmpty, badgeDiameter >= 18 {
            NSGraphicsContext.saveGraphicsState()
            let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
            NSGraphicsContext.current = nsContext

            let fontSize = badgeDiameter * (text.count > 2 ? 0.42 : 0.58)
            let font = NSFont.systemFont(ofSize: fontSize, weight: .heavy)
            let style = NSMutableParagraphStyle()
            style.alignment = .center

            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.white,
                .paragraphStyle: style
            ]

            let attributedString = NSAttributedString(string: text, attributes: attributes)
            let textSize = attributedString.size()
            let textRect = CGRect(
                x: badgeRect.origin.x + (badgeRect.width - textSize.width) / 2,
                y: badgeRect.origin.y + (badgeRect.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )

            attributedString.draw(in: textRect)
            NSGraphicsContext.restoreGraphicsState()
        }

        guard let outputCGImage = context.makeImage() else {
            throw RenderError.failedToExportPNG
        }

        let rep = NSBitmapImageRep(cgImage: outputCGImage)
        guard let pngData = rep.representation(using: .png, properties: [:]) else {
            throw RenderError.failedToExportPNG
        }

        return pngData
    }
}
