import Foundation
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
        print("\n\(TestColor.bold)Duplix Core Engine — Automated Test Suite\(TestColor.reset)\n")

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

        await runAsyncTest("DuplixManager end-to-end clone lifecycle (Create, List, Delete)") {
            let tempRoot = FileManager.default.temporaryDirectory
                .appendingPathComponent("DuplixManagerTest_\(UUID().uuidString)", isDirectory: true)
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

            // 1. Create clone
            let record = try await customManager.createClone(
                sourceAppURL: srcURL,
                customName: "Mock App (Clone 1)"
            )
            try assert(record.name == "Mock App (Clone 1)", "Record name mismatch")
            try assert(FileManager.default.fileExists(atPath: record.appPath), "Cloned app not found on disk")
            try assert(FileManager.default.fileExists(atPath: record.dataPath), "Data directory not found on disk")

            // 2. List clones
            let list = try await customManager.listClones()
            try assert(list.count == 1, "Expected 1 clone in registry, found \(list.count)")
            try assert(list[0].id == record.id, "ID in registry mismatch")

            // 3. Delete clone
            try await customManager.deleteClone(identifierOrName: record.name, deleteData: true)
            try assert(!FileManager.default.fileExists(atPath: record.appPath), "App still exists after deletion")
            try assert(!FileManager.default.fileExists(atPath: record.dataPath), "Data directory still exists after deletion")

            let remaining = try await customManager.listClones()
            try assert(remaining.isEmpty, "Registry should be empty after deletion")
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
