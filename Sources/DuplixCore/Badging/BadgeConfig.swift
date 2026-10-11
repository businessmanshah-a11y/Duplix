import Foundation

public enum BadgePosition: String, Codable, Sendable {
    case bottomRight
    case topRight
    case bottomLeft
    case topLeft
}

public struct BadgeConfig: Codable, Sendable, Equatable {
    public let color: BadgeColor
    public let text: String?
    public let position: BadgePosition
    public let sizeRatio: CGFloat
    public let showBorder: Bool
    public let showShadow: Bool

    public init(
        color: BadgeColor = .blue,
        text: String? = nil,
        position: BadgePosition = .bottomRight,
        sizeRatio: CGFloat = 0.34,
        showBorder: Bool = true,
        showShadow: Bool = true
    ) {
        self.color = color
        self.text = text
        self.position = position
        self.sizeRatio = sizeRatio
        self.showBorder = showBorder
        self.showShadow = showShadow
    }

    public static func automatic(forCloneIndex index: Int) -> BadgeConfig {
        let color = BadgeColor.defaultForIndex(index)
        return BadgeConfig(
            color: color,
            text: "\(index)",
            position: .bottomRight
        )
    }
}
