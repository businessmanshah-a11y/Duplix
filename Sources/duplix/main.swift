import Foundation
import DuplixCore

// ANSI Color Helpers
enum ConsoleColor {
    static let reset = "\u{001B}[0m"
    static let bold = "\u{001B}[1m"
    static let dim = "\u{001B}[2m"
    static let cyan = "\u{001B}[36m"
    static let green = "\u{001B}[32m"
    static let yellow = "\u{001B}[33m"
    static let red = "\u{001B}[31m"
    static let magenta = "\u{001B}[35m"
    static let blue = "\u{001B}[34m"
}

func printBanner() {
    print("""
    \(ConsoleColor.cyan)\(ConsoleColor.bold)Duplix\(ConsoleColor.reset) \(ConsoleColor.dim)— Native macOS App Cloner (Phase 1 Engine)\(ConsoleColor.reset)
    """)
}

func printUsage() {
    printBanner()
    print("""
    \(ConsoleColor.bold)USAGE:\(ConsoleColor.reset)
      duplix <command> [options]

    \(ConsoleColor.bold)COMMANDS:\(ConsoleColor.reset)
      \(ConsoleColor.green)clone\(ConsoleColor.reset) <app-path> [--name <name>] [--overwrite]
            Clones any macOS .app bundle using instant APFS CoW and isolates its data.

      \(ConsoleColor.green)list\(ConsoleColor.reset)
            Lists all created clones, identifiers, engine types, and data paths.

      \(ConsoleColor.green)launch\(ConsoleColor.reset) <id-or-name>
            Runs an isolated instance of the clone simultaneously with existing apps.

      \(ConsoleColor.green)data\(ConsoleColor.reset) <id-or-name>
            Opens the clone's isolated Application Support data folder in Finder.

      \(ConsoleColor.green)reset\(ConsoleColor.reset) <id-or-name>
            Wipes cookies, login sessions, and cache for the clone without touching the app.

      \(ConsoleColor.green)delete\(ConsoleColor.reset) <id-or-name> [--keep-data]
            Unregisters and deletes the clone bundle and its data folder.

      \(ConsoleColor.green)info\(ConsoleColor.reset) <app-path>
            Inspects an application bundle and detects its runtime engine (Electron, Gecko, Native).

      \(ConsoleColor.green)help\(ConsoleColor.reset), --help, -h
            Displays this help message.

    \(ConsoleColor.bold)EXAMPLES:\(ConsoleColor.reset)
      duplix clone "/Applications/Antigravity IDE.app"
      duplix clone "/Applications/Antigravity IDE.app" --name "Antigravity Work"
      duplix launch "Antigravity Work"
      duplix list
    """)
}

func main() async {
    let args = CommandLine.arguments

    guard args.count > 1 else {
        printUsage()
        exit(0)
    }

    let command = args[1].lowercased()
    let manager = DuplixManager.shared

    do {
        switch command {
        case "clone":
            guard args.count > 2 else {
                print("\(ConsoleColor.red)Error:\(ConsoleColor.reset) Missing application path. Example: duplix clone \"/Applications/Antigravity IDE.app\"")
                exit(1)
            }
            let appPath = args[2]
            var customName: String? = nil
            var overwrite = false

            var i = 3
            while i < args.count {
                if args[i] == "--name" && i + 1 < args.count {
                    customName = args[i + 1]
                    i += 2
                } else if args[i] == "--overwrite" {
                    overwrite = true
                    i += 1
                } else {
                    i += 1
                }
            }

            let sourceURL = URL(fileURLWithPath: appPath).standardized
            print("\(ConsoleColor.cyan)⚡️ Inspecting:\(ConsoleColor.reset) \(sourceURL.path)...")

            let detector = EngineDetector()
            let meta = try detector.inspect(appURL: sourceURL)
            print("   \(ConsoleColor.dim)App Name:\(ConsoleColor.reset) \(meta.displayName)")
            print("   \(ConsoleColor.dim)Bundle ID:\(ConsoleColor.reset) \(meta.bundleIdentifier)")
            print("   \(ConsoleColor.dim)Detected Engine:\(ConsoleColor.reset) \(ConsoleColor.magenta)\(meta.engineType.description)\(ConsoleColor.reset)")

            print("\(ConsoleColor.cyan)🚀 Cloning with APFS CoW (Zero extra disk footprint)...\(ConsoleColor.reset)")
            let start = Date()
            let record = try await manager.createClone(
                sourceAppURL: sourceURL,
                customName: customName,
                overwrite: overwrite
            )
            let duration = String(format: "%.2f", Date().timeIntervalSince(start))

            print("""
            \(ConsoleColor.green)\(ConsoleColor.bold)✔ Clone created successfully in \(duration)s!\(ConsoleColor.reset)
               \(ConsoleColor.dim)Name:\(ConsoleColor.reset) \(record.name)
               \(ConsoleColor.dim)Bundle ID:\(ConsoleColor.reset) \(record.cloneBundleID)
               \(ConsoleColor.dim)Location:\(ConsoleColor.reset) \(record.appPath)
               \(ConsoleColor.dim)Isolated Data:\(ConsoleColor.reset) \(record.dataPath)

            \(ConsoleColor.yellow)To run this instance simultaneously, type:\(ConsoleColor.reset)
              duplix launch "\(record.name)"
            """)

        case "list":
            let clones = try await manager.listClones()
            if clones.isEmpty {
                print("\(ConsoleColor.yellow)No clones found.\(ConsoleColor.reset) Create one with: duplix clone <AppPath>")
            } else {
                print("\(ConsoleColor.bold)Registered Duplix Clones (\(clones.count)):\(ConsoleColor.reset)\n")
                for (idx, clone) in clones.enumerated() {
                    let exists = FileManager.default.fileExists(atPath: clone.appPath)
                    let status = exists ? "\(ConsoleColor.green)● Available\(ConsoleColor.reset)" : "\(ConsoleColor.red)✖ Missing\(ConsoleColor.reset)"
                    print("  \(ConsoleColor.bold)\(idx + 1). \(clone.name)\(ConsoleColor.reset) [\(status)]")
                    print("     \(ConsoleColor.dim)Engine:\(ConsoleColor.reset) \(clone.engineType.description)")
                    print("     \(ConsoleColor.dim)ID:\(ConsoleColor.reset) \(clone.id.uuidString)")
                    print("     \(ConsoleColor.dim)Bundle ID:\(ConsoleColor.reset) \(clone.cloneBundleID)")
                    print("     \(ConsoleColor.dim)App Path:\(ConsoleColor.reset) \(clone.appPath)")
                    print("     \(ConsoleColor.dim)Data Path:\(ConsoleColor.reset) \(clone.dataPath)")
                    if let lastLaunch = clone.lastLaunchedAt {
                        print("     \(ConsoleColor.dim)Last Launched:\(ConsoleColor.reset) \(lastLaunch)")
                    }
                    print()
                }
            }

        case "launch":
            guard args.count > 2 else {
                print("\(ConsoleColor.red)Error:\(ConsoleColor.reset) Missing clone name or UUID.")
                exit(1)
            }
            let target = args[2]
            print("\(ConsoleColor.cyan)🚀 Launching isolated instance:\(ConsoleColor.reset) \(target)...")
            try await manager.launchClone(identifierOrName: target)
            print("\(ConsoleColor.green)✔ Instance launched successfully.\(ConsoleColor.reset)")

        case "data":
            guard args.count > 2 else {
                print("\(ConsoleColor.red)Error:\(ConsoleColor.reset) Missing clone name or UUID.")
                exit(1)
            }
            let target = args[2]
            print("\(ConsoleColor.cyan)📂 Opening isolated data directory for:\(ConsoleColor.reset) \(target)...")
            try await manager.openDataDirectory(identifierOrName: target)

        case "reset":
            guard args.count > 2 else {
                print("\(ConsoleColor.red)Error:\(ConsoleColor.reset) Missing clone name or UUID.")
                exit(1)
            }
            let target = args[2]
            print("\(ConsoleColor.yellow)⚠️ Resetting data directory for:\(ConsoleColor.reset) \(target)...")
            try await manager.resetData(identifierOrName: target)
            print("\(ConsoleColor.green)✔ Data reset. Next launch will start with clean session.\(ConsoleColor.reset)")

        case "delete":
            guard args.count > 2 else {
                print("\(ConsoleColor.red)Error:\(ConsoleColor.reset) Missing clone name or UUID.")
                exit(1)
            }
            let target = args[2]
            let keepData = args.contains("--keep-data")
            print("\(ConsoleColor.yellow)🗑 Removing clone:\(ConsoleColor.reset) \(target)...")
            try await manager.deleteClone(identifierOrName: target, deleteData: !keepData)
            print("\(ConsoleColor.green)✔ Clone deleted successfully.\(ConsoleColor.reset)")

        case "info":
            guard args.count > 2 else {
                print("\(ConsoleColor.red)Error:\(ConsoleColor.reset) Missing application path.")
                exit(1)
            }
            let appURL = URL(fileURLWithPath: args[2]).standardized
            let detector = EngineDetector()
            let meta = try detector.inspect(appURL: appURL)
            print("""
            \(ConsoleColor.bold)App Analysis: \(meta.displayName)\(ConsoleColor.reset)
              \(ConsoleColor.dim)Bundle Path:\(ConsoleColor.reset) \(meta.bundleURL.path)
              \(ConsoleColor.dim)Bundle ID:\(ConsoleColor.reset) \(meta.bundleIdentifier)
              \(ConsoleColor.dim)Executable:\(ConsoleColor.reset) \(meta.executableName)
              \(ConsoleColor.dim)Detected Engine:\(ConsoleColor.reset) \(ConsoleColor.magenta)\(meta.engineType.description)\(ConsoleColor.reset)
              \(ConsoleColor.dim)Version:\(ConsoleColor.reset) \(meta.version ?? "Unknown")
            """)

        case "help", "--help", "-h":
            printUsage()

        default:
            print("\(ConsoleColor.red)Unknown command:\(ConsoleColor.reset) \(command)")
            printUsage()
            exit(1)
        }
    } catch {
        print("\(ConsoleColor.red)\(ConsoleColor.bold)Error:\(ConsoleColor.reset) \(error.localizedDescription)")
        exit(1)
    }
}

await main()
