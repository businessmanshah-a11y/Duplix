import SwiftUI
import AppKit
import DuplixCore

public struct IconBadgePreviewView: View {
    public let appURL: URL?
    public let badgeConfig: BadgeConfig?
    public let size: CGFloat

    public init(appURL: URL?, badgeConfig: BadgeConfig?, size: CGFloat = 64) {
        self.appURL = appURL
        self.badgeConfig = badgeConfig
        self.size = size
    }

    private var appIcon: NSImage {
        if let url = appURL, FileManager.default.fileExists(atPath: url.path) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSWorkspace.shared.icon(for: .application)
    }

    public var body: some View {
        ZStack {
            Image(nsImage: appIcon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)

            if let badge = badgeConfig {
                let badgeDiameter = size * badge.sizeRatio
                let margin = size * 0.04

                badgeView(badge: badge, diameter: badgeDiameter)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment(for: badge.position))
                    .padding(margin)
            }
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private func badgeView(badge: BadgeConfig, diameter: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color(cgColor: badge.color.cgColor))
                .shadow(
                    color: badge.showShadow ? Color.black.opacity(0.35) : .clear,
                    radius: diameter * 0.15,
                    x: 0,
                    y: diameter * 0.05
                )

            if badge.showBorder {
                Circle()
                    .strokeBorder(Color.white.opacity(0.95), lineWidth: max(1.5, diameter * 0.08))
            }

            if let text = badge.text, !text.isEmpty {
                Text(text)
                    .font(.system(size: diameter * (text.count > 2 ? 0.38 : 0.52), weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .frame(width: diameter, height: diameter)
    }

    private func alignment(for position: BadgePosition) -> Alignment {
        switch position {
        case .bottomRight: return .bottomTrailing
        case .bottomLeft: return .bottomLeading
        case .topRight: return .topTrailing
        case .topLeft: return .topLeading
        }
    }
}
