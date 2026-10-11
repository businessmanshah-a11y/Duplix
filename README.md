# Duplix

<p align="center">
  <b>The Free, Native, Open-Source macOS App Cloner</b><br>
  Run multiple fully isolated instances of any macOS app simultaneously with independent accounts, data, and Dock icons.
</p>

---

## ✨ Features

- **🚀 Simultaneous Instances:** Run 2, 3, 5, or more copies of any app at the same time without conflicts.
- **🔒 Complete Isolation:** Each clone maintains its own data directory, preferences, cookies, login sessions, and cache.
- **⚡️ Zero Extra Disk Space:** Leverages **APFS Copy-on-Write (CoW)** to duplicate apps instantly without consuming extra storage.
- **🎨 Distinct Dock Icons:** Color-coded badges and custom labels so you instantly recognize which project or account you are working in.
- **🛡 Apple Silicon Native:** Full ad-hoc code signing and Gatekeeper compliance for M1/M2/M3/M4 and Intel Macs.
- **💸 100% Free & Open-Source:** No subscriptions, no license keys, no trial periods.

---

## 🛠 Supported App Architectures

- **Electron / Chromium:** Antigravity IDE, VS Code, Cursor, Slack, Discord, Notion, Postman, etc.
- **Native Cocoa / AppKit:** Native macOS productivity utilities, text editors, players.
- **Gecko:** Firefox, Zen Browser, Thunderbird.
- **More engines coming soon!**

---

## 📁 Documentation

Detailed documentation and technical architecture reports are available in the [`docs/`](./docs) directory:

- [Technical Architecture & Feasibility Report](./docs/FEASIBILITY_AND_ARCHITECTURE.md)
- [Roadmap & 5-Phase Plan](./docs/ROADMAP_AND_PHASES.md)

---

## 🏗 Development Status

Duplix is actively under development.
- **Phase 1 (Core Engine & CLI):** ✅ Completed & Verified (100% automated test coverage)
- **Phase 2 (Icon Badging & Dock Distinction):** ✅ Completed & Verified (CoreGraphics + iconutil)
- **Phase 3 (SwiftUI Native UI):** Queued
- **Phase 4 (Multi-App QA):** Queued
- **Phase 5 (Public DMG Release):** Queued

---

## 💻 CLI Quickstart

Build and run Duplix CLI directly using Swift:

```bash
# Clone any app instantly with APFS CoW & custom Dock badge
swift run duplix clone "/Applications/Antigravity IDE.app" --name "Antigravity Work" --badge-color green --badge-text "W"

# Dynamically update/customize Dock badge color & text without recreating
swift run duplix badge "Antigravity Work" --color purple --text "DEV"

# List all created clones, badge status, and isolated data directories
swift run duplix list

# Launch an isolated instance simultaneously with existing apps
swift run duplix launch "Antigravity Work"

# Open the clone's isolated Application Support data folder
swift run duplix data "Antigravity Work"

# Wipe session/cache for a fresh start without deleting the app
swift run duplix reset "Antigravity Work"

# Delete a clone cleanly
swift run duplix delete "Antigravity Work"

# Run automated test suite (10 automated unit & integration tests)
swift run DuplixTests
```

---

## 📄 License

MIT License. Free for everyone.
