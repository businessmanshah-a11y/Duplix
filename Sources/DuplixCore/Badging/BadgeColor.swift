import Foundation
import CoreGraphics

public struct BadgeColor: Codable, Sendable, Equatable {
    public let red: CGFloat
    public let green: CGFloat
    public let blue: CGFloat
    public let alpha: CGFloat
    public let name: String

    public init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat = 1.0, name: String = "Custom") {
        self.red = min(max(red, 0), 1)
        self.green = min(max(green, 0), 1)
        self.blue = min(max(blue, 0), 1)
        self.alpha = min(max(alpha, 0), 1)
        self.name = name
    }

    public var cgColor: CGColor {
        return CGColor(
            colorSpace: CGColorSpaceCreateDeviceRGB(),
            components: [red, green, blue, alpha]
        ) ?? CGColor(gray: 0.5, alpha: 1.0)
    }

    // Standard Apple Human Interface Guidelines vibrant palette
    public static let blue = BadgeColor(red: 0.0, green: 0.478, blue: 1.0, name: "Blue")          // #007AFF
    public static let green = BadgeColor(red: 0.204, green: 0.780, blue: 0.349, name: "Green")     // #34C759
    public static let orange = BadgeColor(red: 1.0, green: 0.584, blue: 0.0, name: "Orange")       // #FF9500
    public static let purple = BadgeColor(red: 0.686, green: 0.322, blue: 0.871, name: "Purple")   // #AF52DE
    public static let redColor = BadgeColor(red: 1.0, green: 0.231, blue: 0.188, name: "Red")      // #FF3B30
    public static let teal = BadgeColor(red: 0.188, green: 0.690, blue: 0.780, name: "Teal")       // #30B0C7
    public static let pink = BadgeColor(red: 1.0, green: 0.176, blue: 0.333, name: "Pink")         // #FF2D55
    public static let yellow = BadgeColor(red: 1.0, green: 0.800, blue: 0.0, name: "Yellow")       // #FFCC00

    public static let palette: [BadgeColor] = [
        .blue, .green, .orange, .purple, .redColor, .teal, .pink, .yellow
    ]

    /// Returns a distinct default color according to the clone index (1-based or 0-based)
    public static func defaultForIndex(_ index: Int) -> BadgeColor {
        let i = abs(index - 1) % palette.count
        return palette[i]
    }

    /// Parses a string representation (color name or HEX string e.g. "#FF5733" / "34C759")
    public static func fromNameOrHex(_ string: String) -> BadgeColor {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        switch trimmed {
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "red": return .redColor
        case "teal": return .teal
        case "pink": return .pink
        case "yellow": return .yellow
        default:
            break
        }

        // Try HEX parsing
        var hexString = trimmed
        if hexString.hasPrefix("#") {
            hexString.removeFirst()
        }

        guard hexString.count == 6 || hexString.count == 8,
              let hexNumber = UInt64(hexString, radix: 16) else {
            return .blue
        }

        if hexString.count == 6 {
            let r = CGFloat((hexNumber & 0xFF0000) >> 16) / 255.0
            let g = CGFloat((hexNumber & 0x00FF00) >> 8) / 255.0
            let b = CGFloat(hexNumber & 0x0000FF) / 255.0
            return BadgeColor(red: r, green: g, blue: b, alpha: 1.0, name: "#\(hexString.uppercased())")
        } else {
            let r = CGFloat((hexNumber & 0xFF000000) >> 24) / 255.0
            let g = CGFloat((hexNumber & 0x00FF0000) >> 16) / 255.0
            let b = CGFloat((hexNumber & 0x0000FF00) >> 8) / 255.0
            let a = CGFloat(hexNumber & 0x000000FF) / 255.0
            return BadgeColor(red: r, green: g, blue: b, alpha: a, name: "#\(hexString.uppercased())")
        }
    }
}
