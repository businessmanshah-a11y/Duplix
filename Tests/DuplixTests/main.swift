import Foundation
import CoreGraphics
import AppKit
import DuplixCore

// ANSI Colors for Test Reporting
enum TestColor {
    static let reset = "\u{001B}[0m"
    static let bold = "\u{001B}[1m"
    static let green = "\u{001B}[32m"
    static let red = "\u{001B}[31m"
    static let cyan = "\u{001B}[36m"
    static let yellow = "\u{001B}[33m"
}

@MainActor
final class TestSuite {
    var passedCount = 0
    var failedCount = 0

    func runTest(_ name: String, block: () throws -> Void) {
        print("\(TestColor.cyan)▶ Running test:\(TestColor.reset) \(name)... ", terminator: "")
        fflush(stdout)
        do {
            try block()
            print("\(TestColor.green)\(TestColor.bold)PASSED\(TestColor.reset)")
            passedCount += 1
        } catch {
            print("\(TestColor.red)\(TestColor.bold)FAILED\(TestColor.reset)")
            print("  \(TestColor.red)Error:\(TestColor.reset) \(error)")
            failedCount += 1
        }
    }

    func runAsyncTest(_ name: String, block: () async throws -> Void) async {
        print("\(TestColor.cyan)▶ Running test:\(TestColor.reset) \(name)... ", terminator: "")
        fflush(stdout)
        do {
            try await block()
            print("\(TestColor.green)\(TestColor.bold)PASSED\(TestColor.reset)")
            passedCount += 1
        } catch {
            print("\(TestColor.red)\(TestColor.bold)FAILED\(TestColor.reset)")
            print("  \(TestColor.red)Error:\(TestColor.reset) \(error)")
            failedCount += 1
        }
    }

    func assert(_ condition: Bool, _ message: String = "Assertion failed") throws {
        guard condition else {
            throw NSError(domain: "DuplixTestError", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }

    func createMockAppBundle(engine: EngineType) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DuplixTests_\(UUID().uuidString)", isDirectory: true)
        let appURL = tempDir.appendingPathComponent("MockApp.app", isDirectory: true)
        let contentsURL = appURL.appendingPathComponent("Contents", isDirectory: true)
        let macOSURL = contentsURL.appendingPathComponent("MacOS", isDirectory: true)
        let resourcesURL = contentsURL.appendingPathComponent("Resources", isDirectory: true)

        let fileManager = FileManager.default
        try fileManager.createDirectory(at: macOSURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: resourcesURL, withIntermediateDirectories: true)

        // Mock binary
        let binaryURL = macOSURL.appendingPathComponent("MockExecutable")
        try "#!/bin/sh\necho 'Mock'".write(to: binaryURL, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: binaryURL.path)

        // Mock Info.plist
        let plistDict: [String: Any] = [
            "CFBundleIdentifier": "com.example.mockapp",
            "CFBundleName": "MockApp",
            "CFBundleDisplayName": "Mock App Display",
            "CFBundleExecutable": "MockExecutable",
            "CFBundleShortVersionString": "1.0.0"
        ]
        let plistData = try PropertyListSerialization.data(fromPropertyList: plistDict, format: .xml, options: 0)
        let plistURL = contentsURL.appendingPathComponent("Info.plist")
        try plistData.write(to: plistURL)

        // Engine-specific artifacts
        switch engine {
        case .electron:
            let appAsar = resourcesURL.appendingPathComponent("app.asar")
            try "mock electron app.asar".write(to: appAsar, atomically: true, encoding: .utf8)
        case .gecko:
            let omniJa = resourcesURL.appendingPathComponent("omni.ja")
            try "mock omni".write(to: omniJa, atomically: true, encoding: .utf8)
        case .nativeCocoa, .unknown:
            break
        }

        return appURL
    }

    func runAll() async {
        print("\n\(TestColor.bold)Duplix Automated Test Suite (Phases 1 & 2)\(TestColor.reset)\n")

        // Phase 1 Core Tests
        runTest("EngineDetector accurately detects Electron / Chromium framework") {
            let appURL = try createMockAppBundle(engine: .electron)
            defer { try? FileManager.default.removeItem(at: appURL.deletingLastPathComponent()) }

            let detector = EngineDetector()
            let meta = try detector.inspect(appURL: appURL)

            try assert(meta.engineType == .electron, "Expected engine to be Electron")
            try assert(meta.displayName == "Mock App Display", "Display name mismatch")
            try assert(meta.bundleIdentifier == "com.example.mockapp", "Bundle identifier mismatch")
            try assert(meta.executableName == "MockExecutable", "Executable name mismatch")
        }

        runTest("EngineDetector detects Gecko (Firefox/Zen)") {
            let appURL = try createMockAppBundle(engine: .gecko)
            defer { try? FileManager.default.removeItem(at: appURL.deletingLastPathComponent()) }

            let detector = EngineDetector()
            let meta = try detector.inspect(appURL: appURL)
            try assert(meta.engineType == .gecko, "Expected engine to be Gecko")
        }

        runTest("EngineDetector defaults to Native Cocoa") {
            let appURL = try createMockAppBundle(engine: .nativeCocoa)
            defer { try? FileManager.default.removeItem(at: appURL.deletingLastPathComponent()) }

            let detector = EngineDetector()
            let meta = try detector.inspect(appURL: appURL)
            try assert(meta.engineType == .nativeCocoa, "Expected engine to be Native Cocoa")
        }

        runTest("EngineDetector detects Google Chrome Framework as Chromium/Electron engine") {
            let appURL = try createMockAppBundle(engine: .nativeCocoa)
            defer { try? FileManager.default.removeItem(at: appURL.deletingLastPathComponent()) }

            let frameworksURL = appURL.appendingPathComponent("Contents/Frameworks/Google Chrome Framework.framework", isDirectory: true)
            try FileManager.default.createDirectory(at: frameworksURL, withIntermediateDirectories: true)

            let detector = EngineDetector()
            let meta = try detector.inspect(appURL: appURL)
            try assert(meta.engineType == .electron, "Expected Chromium/Chrome framework to be detected as .electron")
        }

        runTest("LauncherGenerator creates Native Cocoa directories and isolates HOME") {
            let appURL = try createMockAppBundle(engine: .nativeCocoa)
            defer { try? FileManager.default.removeItem(at: appURL.deletingLastPathComponent()) }

            let generator = LauncherGenerator()
            let dataDir = "/tmp/duplix_native_data"
            try generator.generateLauncher(
                appBundleURL: appURL,
                originalExecutableName: "MockExecutable",
                launcherExecutableName: "duplix_launcher",
                dataDirectoryPath: dataDir,
                engineType: .nativeCocoa
            )

            let launcherURL = appURL.appendingPathComponent("Contents/MacOS/duplix_launcher")
            let content = try String(contentsOf: launcherURL, encoding: .utf8)
            try assert(content.contains("mkdir -p \"$DATA_DIR/Library/Application Support\""), "Missing App Support dir creation")
            try assert(content.contains("export HOME=\"$DATA_DIR\""), "Missing HOME isolation")
            try assert(content.contains("export CFFIXED_USER_HOME=\"$DATA_DIR\""), "Missing CFFIXED_USER_HOME")
        }

        runTest("PlistModifier modifies BundleID and redirects CFBundleExecutable") {
            let appURL = try createMockAppBundle(engine: .electron)
            defer { try? FileManager.default.removeItem(at: appURL.deletingLastPathComponent()) }

            let modifier = PlistModifier()
            let (originalExec, originalID) = try modifier.modify(
                appBundleURL: appURL,
                newBundleIdentifier: "com.duplix.clone.mockapp.test1",
                displayName: "Mock App (Clone 1)",
                launcherExecutableName: "duplix_launcher"
            )

            try assert(originalExec == "MockExecutable", "Original executable should be preserved")
            try assert(originalID == "com.example.mockapp", "Original bundle ID mismatch")

            let plistURL = appURL.appendingPathComponent("Contents/Info.plist")
            let data = try Data(contentsOf: plistURL)
            let dict = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as! [String: Any]

            try assert(dict["CFBundleIdentifier"] as? String == "com.duplix.clone.mockapp.test1", "BundleID was not updated")
            try assert(dict["CFBundleDisplayName"] as? String == "Mock App (Clone 1)", "DisplayName was not updated")
            try assert(dict["CFBundleName"] as? String == "MockApp", "CFBundleName should be preserved for Helper apps")
            try assert(dict["CFBundleExecutable"] as? String == "duplix_launcher", "CFBundleExecutable not updated")
            try assert(dict["DuplixOriginalExecutable"] as? String == "MockExecutable", "DuplixOriginalExecutable missing")
        }

        runTest("LauncherGenerator creates runnable script with flags and 0755 perms") {
            let appURL = try createMockAppBundle(engine: .electron)
            defer { try? FileManager.default.removeItem(at: appURL.deletingLastPathComponent()) }

            let generator = LauncherGenerator()
            let dataDir = "/tmp/duplix_test_data"
            try generator.generateLauncher(
                appBundleURL: appURL,
                originalExecutableName: "MockExecutable",
                launcherExecutableName: "duplix_launcher",
                dataDirectoryPath: dataDir,
                engineType: .electron
            )

            let launcherURL = appURL.appendingPathComponent("Contents/MacOS/duplix_launcher")
            try assert(FileManager.default.fileExists(atPath: launcherURL.path), "Launcher file not created")

            let content = try String(contentsOf: launcherURL, encoding: .utf8)
            try assert(content.contains("DATA_DIR=\"\(dataDir)\""), "Missing DATA_DIR definition")
            try assert(content.contains("--user-data-dir=\"$DATA_DIR\""), "Missing user-data-dir flag")
            try assert(content.contains("--password-store=basic"), "Missing password-store flag")
            try assert(content.contains("--extensions-dir=\"$DATA_DIR/Extensions\""), "Missing extensions-dir flag")
            try assert(content.contains("--use-mock-keychain"), "Missing mock-keychain flag")

            let attrs = try FileManager.default.attributesOfItem(atPath: launcherURL.path)
            let perms = (attrs[.posixPermissions] as? NSNumber)?.uint16Value
            try assert(perms == 0o755, "Permissions should be 0755")
        }

        runTest("APFSCloner duplicates bundle with APFS CoW") {
            let srcURL = try createMockAppBundle(engine: .nativeCocoa)
            let dstURL = srcURL.deletingLastPathComponent().appendingPathComponent("MockAppCloned.app")
            defer { try? FileManager.default.removeItem(at: srcURL.deletingLastPathComponent()) }

            let cloner = APFSCloner()
            try cloner.clone(sourceURL: srcURL, destinationURL: dstURL)

            try assert(FileManager.default.fileExists(atPath: dstURL.path), "Cloned bundle not found")
            let infoPlist = dstURL.appendingPathComponent("Contents/Info.plist")
            try assert(FileManager.default.fileExists(atPath: infoPlist.path), "Info.plist missing in clone")
        }

        // Phase 2 Badging Tests
        runTest("BadgeColor parses presets and hex codes accurately") {
            let greenColor = BadgeColor.fromNameOrHex("green")
            try assert(greenColor == .green, "Named color green mismatch")

            let hexColor = BadgeColor.fromNameOrHex("#FF5733")
            try assert(abs(hexColor.red - (255.0 / 255.0)) < 0.01, "Hex red mismatch")
            try assert(abs(hexColor.green - (87.0 / 255.0)) < 0.01, "Hex green mismatch")
            try assert(abs(hexColor.blue - (51.0 / 255.0)) < 0.01, "Hex blue mismatch")

            let auto1 = BadgeColor.defaultForIndex(1)
            let auto2 = BadgeColor.defaultForIndex(2)
            try assert(auto1 == .blue, "Clone 1 should get Blue")
            try assert(auto2 == .green, "Clone 2 should get Green")
        }

        runTest("BadgeRenderer draws badge and exports valid PNG data") {
            let width = 128
            let height = 128
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let ctx = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )!
            ctx.setFillColor(CGColor(gray: 0.8, alpha: 1.0))
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
            let baseImage = ctx.makeImage()!

            let renderer = BadgeRenderer()
            let config = BadgeConfig(color: .purple, text: "DEV", position: .bottomRight)
            let pngData = try renderer.renderBadge(on: baseImage, width: width, height: height, config: config)

            try assert(!pngData.isEmpty, "PNG data is empty")
            let loadedRep = NSBitmapImageRep(data: pngData)
            try assert(loadedRep != nil, "Unable to decode generated PNG")
            try assert(loadedRep?.pixelsWide == width, "Width mismatch in rendered PNG")
        }

        runTest("IconManager badges bundle and outputs DuplixBadged.icns") {
            let appURL = try createMockAppBundle(engine: .nativeCocoa)
            defer { try? FileManager.default.removeItem(at: appURL.deletingLastPathComponent()) }

            let iconManager = IconManager()
            let config = BadgeConfig(color: .orange, text: "1", position: .bottomRight)
            let icnsURL = try iconManager.badgeApp(appBundleURL: appURL, config: config)

            try assert(FileManager.default.fileExists(atPath: icnsURL.path), "DuplixBadged.icns was not created")

            // Verify Info.plist updated
            let infoPlistURL = appURL.appendingPathComponent("Contents/Info.plist")
            let data = try Data(contentsOf: infoPlistURL)
            let dict = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as! [String: Any]
            try assert(dict["CFBundleIconFile"] as? String == "DuplixBadged.icns", "CFBundleIconFile not set to DuplixBadged.icns")
        }

        await runAsyncTest("DuplixManager end-to-end badging and updateBadge") {
            let tempRoot = FileManager.default.temporaryDirectory
                .appendingPathComponent("DuplixBadgingTest_\(UUID().uuidString)", isDirectory: true)
            let clonesDir = tempRoot.appendingPathComponent("Clones", isDirectory: true)
            let dataDir = tempRoot.appendingPathComponent("Data", isDirectory: true)
            let registryFile = tempRoot.appendingPathComponent("registry.json", isDirectory: false)
            let srcURL = try createMockAppBundle(engine: .electron)

            defer {
                try? FileManager.default.removeItem(at: tempRoot)
                try? FileManager.default.removeItem(at: srcURL.deletingLastPathComponent())
            }

            let customManager = DuplixManager(
                clonesDirectoryURL: clonesDir,
                dataDirectoryURL: dataDir,
                registryFileURL: registryFile
            )

            // 1. Create clone with custom badge
            let initialBadge = BadgeConfig(color: .green, text: "WORK")
            let record = try await customManager.createClone(
                sourceAppURL: srcURL,
                customName: "Mock App (Clone 1)",
                badgeConfig: initialBadge
            )
            try assert(record.badgeConfig?.color == .green, "Initial badge color mismatch")
            try assert(record.badgeConfig?.text == "WORK", "Initial badge text mismatch")

            // 2. Dynamically update badge
            let updatedBadge = BadgeConfig(color: .purple, text: "DEV")
            let updatedRecord = try await customManager.updateBadge(
                identifierOrName: record.name,
                badgeConfig: updatedBadge
            )
            try assert(updatedRecord.badgeConfig?.color == .purple, "Updated badge color mismatch")
            try assert(updatedRecord.badgeConfig?.text == "DEV", "Updated badge text mismatch")

            // 3. Verify registry persistence
            let list = try await customManager.listClones()
            try assert(list.first?.badgeConfig?.text == "DEV", "Registry did not persist updated badge")

            // Clean up
            try await customManager.deleteClone(identifierOrName: record.name, deleteData: true)
        }

        print("\n-------------------------------------------")
        print("Test Results: \(passedCount) Passed, \(failedCount) Failed")
        print("-------------------------------------------\n")

        if failedCount > 0 {
            exit(1)
        }
    }
}

let suite = TestSuite()
await suite.runAll()
