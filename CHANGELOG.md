# Changelog

## 1.3.0

- Replaced SwiftUI `MenuBarExtra` with a persistent native AppKit status item.
- Added compact red and green status dots with failed-monitor counts.
- Added website creation through the Uptime Kuma management socket.
- Added clickable monitor targets.
- Added settings and website creation windows that close the menu popover cleanly.
- Removed Keychain usage to avoid recurring macOS authorization prompts.
- Added local runtime logging under `~/Library/Logs/KumaBar/KumaBar.log`.
