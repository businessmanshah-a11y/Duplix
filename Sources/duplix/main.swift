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
    \(ConsoleColor.cyan)\(ConsoleColor.bold)Duplix\(ConsoleColor.reset) \(ConsoleColor.dim)— Native macOS App Cloner (v1.1.0)\(ConsoleColor.reset)
    """)
}

func printUsage() {
    printBanner()
    print("""
    \(ConsoleColor.bold)USAGE:\(ConsoleColor.reset)
      duplix <command> [options]

    \(ConsoleColor.bold)COMMANDS:\(ConsoleColor.reset)
      \(ConsoleColor.green)clone\(ConsoleColor.reset) <app-path> [--name <name>] [--badge-color <color>] [--badge-text <text>] [--overwrite]
            Clones any macOS .app bundle using APFS CoW, isolates its data, and applies a distinct Dock badge.

      \(ConsoleColor.green)update\(ConsoleColor.reset) <id-or-name | --all>
            Updates clone bundle(s) to match the latest original app version with ZERO session or data loss.

      \(ConsoleColor.green)check-updates\(ConsoleColor.reset)
            Checks all registered clones for available updates from their source applications.

      \(ConsoleColor.green)badge\(ConsoleColor.reset) <id-or-name> [--color <color>] [--text <text>]
            Updates or customizes the Dock icon badge of an existing clone without recreating it.

      \(ConsoleColor.green)list\(ConsoleColor.reset)
            Lists all created clones, versions, update status, badge status, and data paths.

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

    \(ConsoleColor.bold)BADGE COLORS:\(ConsoleColor.reset)
      blue, green, orange, purple, red, teal, pink, yellow, or custom HEX (e.g. #7B2CBF)

    \(ConsoleColor.bold)EXAMPLES:\(ConsoleColor.reset)
      duplix clone "/Applications/Antigravity IDE.app"
      duplix check-updates
      duplix update "Antigravity IDE (Clone 1)"
      duplix update --all
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
            var badgeColorName: String? = nil
            var badgeText: String? = nil
            var overwrite = false

            var i = 3
            while i < args.count {
                if args[i] == "--name" && i + 1 < args.count {
                    customName = args[i + 1]
                    i += 2
                } else if args[i] == "--badge-color" && i + 1 < args.count {
                    badgeColorName = args[i + 1]
                    i += 2
                } else if args[i] == "--badge-text" && i + 1 < args.count {
                    badgeText = args[i + 1]
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

            let badgeConfig: BadgeConfig?
            if let badgeColorName = badgeColorName {
                let color = BadgeColor.fromNameOrHex(badgeColorName)
                badgeConfig = BadgeConfig(color: color, text: badgeText, position: .bottomRight)
            } else if let badgeText = badgeText {
                badgeConfig = BadgeConfig(color: .blue, text: badgeText, position: .bottomRight)
            } else {
                badgeConfig = nil
            }

            print("\(ConsoleColor.cyan)🚀 Cloning with APFS CoW & Badging Dock Icon...\(ConsoleColor.reset)")
            let start = Date()
            let record = try await manager.createClone(
                sourceAppURL: sourceURL,
                customName: customName,
                badgeConfig: badgeConfig,
                overwrite: overwrite
            )
            let duration = String(format: "%.2f", Date().timeIntervalSince(start))

            let badgeDesc = record.badgeConfig.map { "\($0.color.name) (Text: '\($0.text ?? "-")')" } ?? "Default"

            print("""
            \(ConsoleColor.green)\(ConsoleColor.bold)✔ Clone created successfully in \(duration)s!\(ConsoleColor.reset)
               \(ConsoleColor.dim)Name:\(ConsoleColor.reset) \(record.name)
               \(ConsoleColor.dim)Bundle ID:\(ConsoleColor.reset) \(record.cloneBundleID)
               \(ConsoleColor.dim)Dock Badge:\(ConsoleColor.reset) \(ConsoleColor.green)\(badgeDesc)\(ConsoleColor.reset)
               \(ConsoleColor.dim)Location:\(ConsoleColor.reset) \(record.appPath)
               \(ConsoleColor.dim)Isolated Data:\(ConsoleColor.reset) \(record.dataPath)

            \(ConsoleColor.yellow)To run this instance simultaneously, type:\(ConsoleColor.reset)
              duplix launch "\(record.name)"
            """)

        case "check-updates":
            print("\(ConsoleColor.cyan)🔍 Checking clones for available updates from original apps...\(ConsoleColor.reset)\n")
            let clones = try await manager.listClones()
            if clones.isEmpty {
                print("\(ConsoleColor.yellow)No clones found to check.\(ConsoleColor.reset)")
                break
            }

            var outdatedCount = 0
            for (idx, clone) in clones.enumerated() {
                let updateInfo = try? await manager.checkUpdate(for: clone)
                let currentVer = updateInfo?.cloneVersion ?? "Unknown"
                let sourceVer = updateInfo?.sourceVersion ?? "Unknown"

                print("  \(ConsoleColor.bold)\(idx + 1). \(clone.name)\(ConsoleColor.reset)")
                print("     \(ConsoleColor.dim)Current Clone Version:\(ConsoleColor.reset) v\(currentVer)")
                print("     \(ConsoleColor.dim)Source App Version:\(ConsoleColor.reset)    v\(sourceVer)")

                if let info = updateInfo, info.hasUpdate {
                    outdatedCount += 1
                    print("     \(ConsoleColor.yellow)\(ConsoleColor.bold)➔ UPDATE AVAILABLE:\(ConsoleColor.reset) \(ConsoleColor.dim)v\(currentVer) ➔\(ConsoleColor.reset) \(ConsoleColor.green)v\(sourceVer)\(ConsoleColor.reset)")
                    print("     \(ConsoleColor.dim)Run to update:\(ConsoleColor.reset) duplix update \"\(clone.name)\"")
                } else if updateInfo != nil {
                    print("     \(ConsoleColor.green)✔ Up to date\(ConsoleColor.reset)")
                } else {
                    print("     \(ConsoleColor.dim)Source app not currently found on disk.\(ConsoleColor.reset)")
                }
                print()
            }

            if outdatedCount > 0 {
                print("\(ConsoleColor.yellow)\(ConsoleColor.bold)Summary:\(ConsoleColor.reset) \(outdatedCount) clone(s) have updates available. Run \(ConsoleColor.green)duplix update --all\(ConsoleColor.reset) to update.")
            } else {
                print("\(ConsoleColor.green)\(ConsoleColor.bold)All clones are up to date with their original applications.\(ConsoleColor.reset)")
            }

        case "update":
            guard args.count > 2 else {
                print("\(ConsoleColor.red)Error:\(ConsoleColor.reset) Missing clone name/UUID or '--all'. Example: duplix update \"Antigravity IDE (Clone 1)\"")
                exit(1)
            }

            let target = args[2]
            if target == "--all" {
                print("\(ConsoleColor.cyan)🔄 Checking and updating all outdated clones...\(ConsoleColor.reset)\n")
                let clones = try await manager.listClones()
                var updatedCount = 0

                for clone in clones {
                    if let info = try? await manager.checkUpdate(for: clone), info.hasUpdate {
                        print("\(ConsoleColor.cyan)⚡ Updating \(clone.name)...\(ConsoleColor.reset) (\(info.cloneVersion) ➔ \(info.sourceVersion))")
                        let start = Date()
                        do {
                            let updated = try await manager.updateClone(identifierOrName: clone.id.uuidString)
                            let duration = String(format: "%.2f", Date().timeIntervalSince(start))
                            print("  \(ConsoleColor.green)✔ Updated successfully in \(duration)s (Session data preserved: \(updated.dataPath))\(ConsoleColor.reset)")
                            updatedCount += 1
                        } catch {
                            print("  \(ConsoleColor.red)✖ Failed to update \(clone.name): \(error.localizedDescription)\(ConsoleColor.reset)")
                        }
                    }
                }

                if updatedCount == 0 {
                    print("\(ConsoleColor.green)All clones are already up to date.\(ConsoleColor.reset)")
                } else {
                    print("\n\(ConsoleColor.green)\(ConsoleColor.bold)✔ Finished updating \(updatedCount) clone(s).\(ConsoleColor.reset)")
                }
            } else {
                print("\(ConsoleColor.cyan)🔄 Updating clone: \(target)...\(ConsoleColor.reset)")
                let start = Date()
                let updated = try await manager.updateClone(identifierOrName: target)
                let duration = String(format: "%.2f", Date().timeIntervalSince(start))

                print("""
                \(ConsoleColor.green)\(ConsoleColor.bold)✔ Clone updated successfully in \(duration)s!\(ConsoleColor.reset)
                   \(ConsoleColor.dim)Name:\(ConsoleColor.reset) \(updated.name)
                   \(ConsoleColor.dim)App Path:\(ConsoleColor.reset) \(updated.appPath)
                   \(ConsoleColor.dim)Session Data (Untouched):\(ConsoleColor.reset) \(ConsoleColor.green)\(updated.dataPath)\(ConsoleColor.reset)

                \(ConsoleColor.yellow)You can now launch the updated instance:\(ConsoleColor.reset)
                  duplix launch "\(updated.name)"
                """)
            }

        case "badge":
            guard args.count > 2 else {
                print("\(ConsoleColor.red)Error:\(ConsoleColor.reset) Missing clone name or UUID. Example: duplix badge \"Antigravity (Clone 1)\" --color purple --text \"DEV\"")
                exit(1)
            }
            let target = args[2]
            var badgeColorName = "blue"
            var badgeText: String? = nil

            var i = 3
            while i < args.count {
                if (args[i] == "--color" || args[i] == "-c") && i + 1 < args.count {
                    badgeColorName = args[i + 1]
                    i += 2
                } else if (args[i] == "--text" || args[i] == "-t") && i + 1 < args.count {
                    badgeText = args[i + 1]
                    i += 2
                } else {
                    i += 1
                }
            }

            let color = BadgeColor.fromNameOrHex(badgeColorName)
            let newConfig = BadgeConfig(color: color, text: badgeText, position: .bottomRight)

            print("\(ConsoleColor.cyan)🎨 Updating icon badge for:\(ConsoleColor.reset) \(target)...")
            let updated = try await manager.updateBadge(identifierOrName: target, badgeConfig: newConfig)
            print("""
            \(ConsoleColor.green)\(ConsoleColor.bold)✔ Icon badge updated successfully!\(ConsoleColor.reset)
               \(ConsoleColor.dim)Clone:\(ConsoleColor.reset) \(updated.name)
               \(ConsoleColor.dim)New Badge:\(ConsoleColor.reset) \(ConsoleColor.green)\(color.name) (Text: '\(badgeText ?? "-")')\(ConsoleColor.reset)
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
                    let badgeInfo = clone.badgeConfig.map { "\($0.color.name) [\($0.text ?? "-")]" } ?? "None"

                    let updateInfo = try? await manager.checkUpdate(for: clone)
                    let versionText = updateInfo.map { "v\($0.cloneVersion)" } ?? ""

                    print("  \(ConsoleColor.bold)\(idx + 1). \(clone.name)\(ConsoleColor.reset) [\(status)] \(versionText)")
                    print("     \(ConsoleColor.dim)Engine:\(ConsoleColor.reset) \(clone.engineType.description)")
                    print("     \(ConsoleColor.dim)Dock Badge:\(ConsoleColor.reset) \(ConsoleColor.cyan)\(badgeInfo)\(ConsoleColor.reset)")

                    if let info = updateInfo, info.hasUpdate {
                        print("     \(ConsoleColor.yellow)\(ConsoleColor.bold)Update:\(ConsoleColor.reset)     \(ConsoleColor.yellow)v\(info.cloneVersion) ➔ v\(info.sourceVersion) Available (run: duplix update \"\(clone.name)\")\(ConsoleColor.reset)")
                    }

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
