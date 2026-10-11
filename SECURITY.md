# Security Policy & Architecture

## Security Philosophy

Duplix is designed as a **privacy-first, local-only macOS utility**. We hold a strict zero-telemetry and zero-cloud principle: **your computer and data remain entirely yours.**

---

## 1. Zero Network Telemetry Guarantee

- **No Outbound Requests:** Duplix does not collect analytics, track usage, or transmit diagnostic data.
- **No Remote Servers:** Duplix communicates with zero external APIs or third-party servers.
- **Offline First:** All operations (cloning, badging, process management, and data wiping) run 100% locally on your machine.

---

## 2. Principle of Least Privilege (No Root Required)

- Duplix does **NOT** require `sudo`, root privileges, or Kernel Extensions (KEXTs).
- All operations execute strictly within standard user-space permissions.
- Duplix clones applications either to `/Applications` (if write permissions exist) or to user-level `~/Applications`.

---

## 3. Session & Data Isolation

- Each cloned application is given a unique bundle identifier (e.g. `com.company.app.duplix.<shortId>`).
- Data directories are isolated to `~/Library/Application Support/Duplix/data/<shortId>`.
- For Chromium/Electron applications, independent user directories are enforced via `--user-data-dir` and isolated socket descriptors.
- For Native Cocoa applications, the runtime launcher redirects `HOME` to the clone's dedicated container to prevent shared cookies or keychain conflicts.

---

## 4. Code Signing & Gatekeeper Safety

- macOS Gatekeeper enforces code signature verification on Apple Silicon. When an application's `Info.plist` or assets are modified, the original cryptographic signature becomes invalid.
- Duplix utilizes macOS native `codesign` utility to strip quarantine flags (`xattr -dr com.apple.quarantine`) and apply an **ad-hoc local code signature** (`codesign --force --deep --sign -`).
- This allows native launch on Apple Silicon (M1/M2/M3/M4) without installing custom root certificates or compromising System Integrity Protection (SIP).

---

## 5. Reporting a Security Vulnerability

If you discover any potential security vulnerability or privacy concern within Duplix:
1. Please **do not** open a public GitHub issue.
2. Send a confidential report directly via GitHub Security Advisories or to the project maintainers.
3. We will respond promptly, investigate the issue, and provide a patch.
