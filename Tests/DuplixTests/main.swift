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

        runTest("LauncherGenerator creates runnable script with Keychain, HOME, and GEMINI_DIR isolation") {
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
            try assert(content.contains("export HOME=\"$DATA_DIR\""), "Missing HOME isolation for Electron")
            try assert(content.contains("export GEMINI_DIR=\"$DATA_DIR/.gemini\""), "Missing GEMINI_DIR isolation")
            try assert(content.contains("export ANTIGRAVITY_GEMINI_DIR=\"$DATA_DIR/.gemini\""), "Missing ANTIGRAVITY_GEMINI_DIR isolation")
            try assert(!content.contains("export ANTIGRAVITY_APP_DATA_DIR="), "Should not hardcode ANTIGRAVITY_APP_DATA_DIR")
            try assert(content.contains("/usr/bin/security create-keychain"), "Missing isolated keychain creation")

            if let homeRange = content.range(of: "export HOME=\"$DATA_DIR\""),
               let kcRange = content.range(of: "/usr/bin/security create-keychain") {
                try assert(homeRange.lowerBound < kcRange.lowerBound, "HOME must be exported before security create-keychain")
            } else {
                try assert(false, "Expected both HOME export and security create-keychain")
            }

            let attrs = try FileManager.default.attributesOfItem(atPath: launcherURL.path)
            let perms = (attrs[.posixPermissions] as? NSNumber)?.uint16Value
            try assert(perms == 0o755, "Permissions should be 0755")
        }

        runTest("LauncherGenerator runtime execution isolates HOME, Keychain, and bridges .gemini/bin") {
            let fileManager = FileManager.default
            let appURL = try createMockAppBundle(engine: .electron)
            let sandboxRoot = fileManager.temporaryDirectory
                .appendingPathComponent("DuplixExecTest_\(UUID().uuidString)", isDirectory: true)
            let fakeRealHome = sandboxRoot.appendingPathComponent("RealHome", isDirectory: true)
            let dataDir = sandboxRoot.appendingPathComponent("CloneData", isDirectory: true)
            defer {
                try? fileManager.removeItem(at: appURL.deletingLastPathComponent())
                try? fileManager.removeItem(at: sandboxRoot)
            }

            try fileManager.createDirectory(at: fakeRealHome.appendingPathComponent(".gemini/bin", isDirectory: true), withIntermediateDirectories: true)
            try "fake-agy".write(to: fakeRealHome.appendingPathComponent(".gemini/bin/agy"), atomically: true, encoding: .utf8)
            try "user=test".write(to: fakeRealHome.appendingPathComponent(".gitconfig"), atomically: true, encoding: .utf8)

            // Replace MockExecutable with a script that dumps isolated env & default keychain
            let mockExecURL = appURL.appendingPathComponent("Contents/MacOS/MockExecutable")
            let dumpScript = """
            #!/bin/bash
            echo "HOME=$HOME"
            echo "GEMINI_DIR=$GEMINI_DIR"
            echo "ANTIGRAVITY_GEMINI_DIR=$ANTIGRAVITY_GEMINI_DIR"
            echo "INHERITED_APP_DATA=${ANTIGRAVITY_APP_DATA_DIR:-UNSET}"
            echo "DEFAULT_KC=$(/usr/bin/security default-keychain | tr -d ' \"')"
            echo "LIST_KC=$(/usr/bin/security list-keychains | tr '\n' '|')"
            echo "ARGS=$*"
            """
            try dumpScript.write(to: mockExecURL, atomically: true, encoding: .utf8)
            try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: mockExecURL.path)

            let generator = LauncherGenerator()
            try generator.generateLauncher(
                appBundleURL: appURL,
                originalExecutableName: "MockExecutable",
                launcherExecutableName: "duplix_launcher",
                dataDirectoryPath: dataDir.path,
                engineType: .electron
            )

            let process = Process()
            process.executableURL = appURL.appendingPathComponent("Contents/MacOS/duplix_launcher")
            var env = ProcessInfo.processInfo.environment
            env["HOME"] = fakeRealHome.path
            env["ANTIGRAVITY_APP_DATA_DIR"] = "/leaked/parent/path"
            process.environment = env

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            try process.run()
            process.waitUntilExit()

            let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""
            try assert(process.terminationStatus == 0, "Launcher exited with \(process.terminationStatus): \(output)")
            try assert(output.contains("HOME=\(dataDir.path)"), "HOME was not isolated: \(output)")
            try assert(output.contains("GEMINI_DIR=\(dataDir.path)/.gemini"), "GEMINI_DIR mismatch: \(output)")
            try assert(output.contains("ANTIGRAVITY_GEMINI_DIR=\(dataDir.path)/.gemini"), "ANTIGRAVITY_GEMINI_DIR mismatch: \(output)")
            try assert(output.contains("INHERITED_APP_DATA=UNSET"), "Inherited ANTIGRAVITY_APP_DATA_DIR should be unset: \(output)")
            try assert(output.contains("duplix.keychain-db"), "Isolated keychain not set as default: \(output)")
            try assert(!output.contains("login.keychain"), "Host login.keychain must not appear in clone keychain search list: \(output)")
            try assert(fileManager.fileExists(atPath: dataDir.appendingPathComponent(".gemini/bin/agy").path), "Symlink to .gemini/bin/agy missing")
            try assert(fileManager.fileExists(atPath: dataDir.appendingPathComponent(".gitconfig").path), "Symlink to .gitconfig missing")
        }

        runTest("PlistModifier isolates CFBundleURLTypes and is idempotent on repair") {
            let appURL = try createMockAppBundle(engine: .electron)
            defer { try? FileManager.default.removeItem(at: appURL.deletingLastPathComponent()) }

            // Add CFBundleURLTypes to mock plist
            let plistURL = appURL.appendingPathComponent("Contents/Info.plist")
            var dict = try PropertyListSerialization.propertyList(from: Data(contentsOf: plistURL), options: [], format: nil) as! [String: Any]
            dict["CFBundleURLTypes"] = [
                ["CFBundleURLName": "Antigravity IDE", "CFBundleURLSchemes": ["antigravity-ide"]]
            ]
            try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0).write(to: plistURL)

            let modifier = PlistModifier()
            let (exec1, origID1) = try modifier.modify(
                appBundleURL: appURL,
                newBundleIdentifier: "com.duplix.clone.mockapp.abcd1234",
                displayName: "Mock App (Clone 1)",
                launcherExecutableName: "duplix_launcher"
            )
            try assert(exec1 == "MockExecutable", "First modify original executable mismatch")
            try assert(origID1 == "com.example.mockapp", "First modify original bundle ID mismatch")

            // Call modify again (simulating repairClone)
            let (exec2, origID2) = try modifier.modify(
                appBundleURL: appURL,
                newBundleIdentifier: "com.duplix.clone.mockapp.abcd1234",
                displayName: "Mock App (Clone 1)",
                launcherExecutableName: "duplix_launcher"
            )
            try assert(exec2 == "MockExecutable", "Idempotent modify must preserve original executable, not overwrite with duplix_launcher")
            try assert(origID2 == "com.example.mockapp", "Idempotent modify must preserve original bundle ID")

            let updatedDict = try PropertyListSerialization.propertyList(from: Data(contentsOf: plistURL), options: [], format: nil) as! [String: Any]
            let urlTypes = updatedDict["CFBundleURLTypes"] as? [[String: Any]]
            let schemes = urlTypes?.first?["CFBundleURLSchemes"] as? [String]
            try assert(schemes == ["antigravity-ide-clone-abcd1234"], "URL schemes should be suffixed and not double-suffixed: \(String(describing: schemes))")
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

        await runAsyncTest("DuplixManager checkUpdate detects version mismatch and updateClone safely refreshes bundle") {
            let fileManager = FileManager.default
            let tempRoot = fileManager.temporaryDirectory
                .appendingPathComponent("DuplixUpdateTest_\(UUID().uuidString)", isDirectory: true)
            let clonesDir = tempRoot.appendingPathComponent("Clones", isDirectory: true)
            let dataDir = tempRoot.appendingPathComponent("Data", isDirectory: true)
            let registryFile = tempRoot.appendingPathComponent("registry.json", isDirectory: false)
            let srcURL = try createMockAppBundle(engine: .electron)

            defer {
                try? fileManager.removeItem(at: tempRoot)
                try? fileManager.removeItem(at: srcURL.deletingLastPathComponent())
            }

            let customManager = DuplixManager(
                clonesDirectoryURL: clonesDir,
                dataDirectoryURL: dataDir,
                registryFileURL: registryFile
            )

            // 1. Create clone with initial v1.0.0
            let record = try await customManager.createClone(
                sourceAppURL: srcURL,
                customName: "Updatable App"
            )

            // Simulate user session data inside dataPath
            let sessionFile = URL(fileURLWithPath: record.dataPath).appendingPathComponent("user_session.txt")
            try "USER_LOGGED_IN_TOKEN_12345".write(to: sessionFile, atomically: true, encoding: .utf8)

            // Verify initial status: up to date
            let initialUpdate = try await customManager.checkUpdate(for: record)
            try assert(initialUpdate?.hasUpdate == false, "Clone should initially be up to date")

            // 2. Simulate source app updating from 1.0.0 to 2.0.0
            let srcPlistURL = srcURL.appendingPathComponent("Contents/Info.plist")
            var srcPlist = try PropertyListSerialization.propertyList(from: Data(contentsOf: srcPlistURL), options: [], format: nil) as! [String: Any]
            srcPlist["CFBundleShortVersionString"] = "2.0.0"
            let newPlistData = try PropertyListSerialization.data(fromPropertyList: srcPlist, format: .xml, options: 0)
            try newPlistData.write(to: srcPlistURL)

            // 3. Check for update: must detect update available (1.0.0 -> 2.0.0)
            let detectedUpdate = try await customManager.checkUpdate(for: record)
            try assert(detectedUpdate?.hasUpdate == true, "Should detect update available")
            try assert(detectedUpdate?.cloneVersion == "1.0.0", "Clone version should be 1.0.0")
            try assert(detectedUpdate?.sourceVersion == "2.0.0", "Source version should be 2.0.0")

            // 4. Perform atomic update
            let updatedRecord = try await customManager.updateClone(identifierOrName: record.name)
            try assert(updatedRecord.name == "Updatable App", "Name should remain unchanged")

            // 5. Verify bundle updated to 2.0.0
            let clonePlistURL = URL(fileURLWithPath: updatedRecord.appPath).appendingPathComponent("Contents/Info.plist")
            let clonePlist = try PropertyListSerialization.propertyList(from: Data(contentsOf: clonePlistURL), options: [], format: nil) as! [String: Any]
            try assert((clonePlist["CFBundleShortVersionString"] as? String) == "2.0.0", "Clone bundle was not updated to 2.0.0")

            // 6. CRUCIAL: Verify user session data is 100% intact!
            try assert(fileManager.fileExists(atPath: sessionFile.path), "Session file was deleted!")
            let readSession = try String(contentsOf: sessionFile, encoding: .utf8)
            try assert(readSession == "USER_LOGGED_IN_TOKEN_12345", "Session data was altered or corrupted!")

            // 7. Verify checkUpdate now reports up to date
            let postUpdate = try await customManager.checkUpdate(for: updatedRecord)
            try assert(postUpdate?.hasUpdate == false, "Clone should now be up to date")

            // Clean up
            try await customManager.deleteClone(identifierOrName: record.name, deleteData: true)
        }

        await runAsyncTest("DuplixManager repairClone upgrades launcher without losing session data") {
            let fileManager = FileManager.default
            let tempRoot = fileManager.temporaryDirectory
                .appendingPathComponent("DuplixRepairTest_\(UUID().uuidString)", isDirectory: true)
            let clonesDir = tempRoot.appendingPathComponent("Clones", isDirectory: true)
            let dataDir = tempRoot.appendingPathComponent("Data", isDirectory: true)
            let registryFile = tempRoot.appendingPathComponent("registry.json", isDirectory: false)
            let srcURL = try createMockAppBundle(engine: .electron)

            defer {
                try? fileManager.removeItem(at: tempRoot)
                try? fileManager.removeItem(at: srcURL.deletingLastPathComponent())
            }

            let customManager = DuplixManager(
                clonesDirectoryURL: clonesDir,
                dataDirectoryURL: dataDir,
                registryFileURL: registryFile
            )

            let record = try await customManager.createClone(
                sourceAppURL: srcURL,
                customName: "Repairable App"
            )

            // Overwrite launcher with legacy script to simulate old clone
            let launcherURL = URL(fileURLWithPath: record.appPath).appendingPathComponent("Contents/MacOS/duplix_launcher")
            try "#!/bin/bash\n# legacy launcher\n".write(to: launcherURL, atomically: true, encoding: .utf8)

            // Simulate user data
            let sessionFile = URL(fileURLWithPath: record.dataPath).appendingPathComponent("user_data.txt")
            try "IMPORTANT_SESSION_DATA".write(to: sessionFile, atomically: true, encoding: .utf8)

            let repaired = try await customManager.repairClone(identifierOrName: record.name)
            try assert(repaired.name == "Repairable App", "Clone name mismatch after repair")

            let newLauncherContent = try String(contentsOf: launcherURL, encoding: .utf8)
            try assert(newLauncherContent.contains("duplix.keychain-db"), "Repaired launcher missing isolated keychain")
            try assert(newLauncherContent.contains("export HOME=\"$DATA_DIR\""), "Repaired launcher missing HOME isolation")

            // Verify user data untouched
            let readSession = try String(contentsOf: sessionFile, encoding: .utf8)
            try assert(readSession == "IMPORTANT_SESSION_DATA", "Session data was altered during repair")

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
