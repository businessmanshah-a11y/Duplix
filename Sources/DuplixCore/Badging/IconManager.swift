import Foundation
import AppKit

public struct IconManager: Sendable {
    public init() {}

    private let badgeRenderer = BadgeRenderer()
    private let codeSigner = CodeSigner()

    public enum IconError: LocalizedError, Sendable {
        case iconNotFound(URL)
        case iconutilExtractionFailed(Int32, String)
        case iconutilPackingFailed(Int32, String)
        case noValidImagesInIconset(URL)

        public var errorDescription: String? {
            switch self {
            case .iconNotFound(let url):
                return "No valid .icns file found in \(url.path)"
            case .iconutilExtractionFailed(let code, let msg):
                return "iconutil extraction failed (exit code \(code)): \(msg)"
            case .iconutilPackingFailed(let code, let msg):
                return "iconutil packing failed (exit code \(code)): \(msg)"
            case .noValidImagesInIconset(let url):
                return "No valid PNG images found in iconset at \(url.path)"
            }
        }
    }

    /// Finds the primary .icns file inside Contents/Resources/ of an app bundle.
    public func findSourceIconURL(in appBundleURL: URL, preferredName: String? = nil) -> URL? {
        let resourcesURL = appBundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)

        let fileManager = FileManager.default

        if let preferred = preferredName, !preferred.isEmpty {
            let directURL = resourcesURL.appendingPathComponent(preferred, isDirectory: false)
            if fileManager.fileExists(atPath: directURL.path) {
                return directURL
            }

            let icnsURL = resourcesURL.appendingPathComponent("\(preferred).icns", isDirectory: false)
            if fileManager.fileExists(atPath: icnsURL.path) {
                return icnsURL
            }
        }

        guard let enumerator = fileManager.enumerator(
            at: resourcesURL,
            includingPropertiesForKeys: nil,
            options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles]
        ) else { return nil }

        for case let url as URL in enumerator {
            if url.pathExtension.lowercased() == "icns" && !url.lastPathComponent.contains("DuplixBadged") {
                return url
            }
        }

        return nil
    }

    /// Extracts, badges, re-packs, and updates the icon of a cloned macOS app bundle.
    @discardableResult
    public func badgeApp(
        appBundleURL: URL,
        preferredIconName: String? = nil,
        config: BadgeConfig
    ) throws -> URL {
        let fileManager = FileManager.default
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("DuplixBadge_\(UUID().uuidString)", isDirectory: true)
        let iconsetDir = tempRoot.appendingPathComponent("icon.iconset", isDirectory: true)

        try fileManager.createDirectory(at: iconsetDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempRoot) }

        let sourceIconURL = findSourceIconURL(in: appBundleURL, preferredName: preferredIconName)

        if let sourceIconURL = sourceIconURL {
            // Extract .icns to .iconset
            let extractProcess = Process()
            extractProcess.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
            extractProcess.arguments = ["-c", "iconset", sourceIconURL.path, "-o", iconsetDir.path]

            let errorPipe = Pipe()
            extractProcess.standardError = errorPipe

            try extractProcess.run()
            extractProcess.waitUntilExit()

            if extractProcess.terminationStatus != 0 {
                // If extraction failed, fallback to workspace generation
                try generateFallbackIconset(for: appBundleURL, into: iconsetDir)
            }
        } else {
            // No .icns found in Resources, generate from NSWorkspace icon
            try generateFallbackIconset(for: appBundleURL, into: iconsetDir)
        }

        // Apply badge to all PNGs in .iconset
        let pngFiles = try fileManager.contentsOfDirectory(
            at: iconsetDir,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ).filter { $0.pathExtension.lowercased() == "png" }

        guard !pngFiles.isEmpty else {
            throw IconError.noValidImagesInIconset(iconsetDir)
        }

        for pngURL in pngFiles {
            try badgeRenderer.applyBadge(toImageAt: pngURL, destinationURL: pngURL, config: config)
        }

        // Pack back to .icns
        let resourcesURL = appBundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
        let targetICNSURL = resourcesURL.appendingPathComponent("DuplixBadged.icns", isDirectory: false)

        if fileManager.fileExists(atPath: targetICNSURL.path) {
            try fileManager.removeItem(at: targetICNSURL)
        }

        let packProcess = Process()
        packProcess.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
        packProcess.arguments = ["-c", "icns", iconsetDir.path, "-o", targetICNSURL.path]

        let packErrorPipe = Pipe()
        packProcess.standardError = packErrorPipe

        try packProcess.run()
        packProcess.waitUntilExit()

        guard packProcess.terminationStatus == 0 else {
            let errorData = packErrorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown pack error"
            throw IconError.iconutilPackingFailed(packProcess.terminationStatus, errorString.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        // Update Info.plist to reference DuplixBadged.icns
        let infoPlistURL = appBundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Info.plist", isDirectory: false)

        if fileManager.fileExists(atPath: infoPlistURL.path) {
            let data = try Data(contentsOf: infoPlistURL)
            var format = PropertyListSerialization.PropertyListFormat.xml
            if var dict = try PropertyListSerialization.propertyList(from: data, options: .mutableContainersAndLeaves, format: &format) as? [String: Any] {
                dict["CFBundleIconFile"] = "DuplixBadged.icns"
                let updatedData = try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)
                try updatedData.write(to: infoPlistURL, options: .atomic)
            }
        }

        // Re-sign bundle
        try codeSigner.resign(bundleURL: appBundleURL)

        // Invalidate LaunchServices icon cache
        let touchProcess = Process()
        touchProcess.executableURL = URL(fileURLWithPath: "/usr/bin/touch")
        touchProcess.arguments = [appBundleURL.path]
        try? touchProcess.run()
        touchProcess.waitUntilExit()

        return targetICNSURL
    }

    /// Generates standard icon resolutions from NSWorkspace system icon when no .icns is present.
    private func generateFallbackIconset(for appBundleURL: URL, into iconsetDir: URL) throws {
        let appIcon = NSWorkspace.shared.icon(forFile: appBundleURL.path)
        let sizes: [(String, Int)] = [
            ("icon_16x16.png", 16),
            ("icon_16x16@2x.png", 32),
            ("icon_32x32.png", 32),
            ("icon_32x32@2x.png", 64),
            ("icon_128x128.png", 128),
            ("icon_128x128@2x.png", 256),
            ("icon_256x256.png", 256),
            ("icon_256x256@2x.png", 512),
            ("icon_512x512.png", 512),
            ("icon_512x512@2x.png", 1024)
        ]

        for (filename, dimension) in sizes {
            let targetURL = iconsetDir.appendingPathComponent(filename)
            let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: dimension,
                pixelsHigh: dimension,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )

            guard let rep = rep else { continue }
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

            appIcon.draw(
                in: NSRect(x: 0, y: 0, width: dimension, height: dimension),
                from: .zero,
                operation: .copy,
                fraction: 1.0
            )

            NSGraphicsContext.restoreGraphicsState()

            if let pngData = rep.representation(using: .png, properties: [:]) {
                try pngData.write(to: targetURL)
            }
        }
    }
}
