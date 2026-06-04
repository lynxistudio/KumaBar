# Changelog

## 1.3.1

- Reconnects monitor refreshes after macOS wake.
- Rebuilds the refresh loop when the user presses refresh.
- Uses a fresh network session for every metrics request.
- Shows the last successful refresh time and marks stale data as unavailable.
- Explicitly synchronizes the native status item after refresh success or failure.

## 1.3.0

- Replaced SwiftUI `MenuBarExtra` with a persistent native AppKit status item.
- Added compact red and green status dots with failed-monitor counts.
- Added website creation through the Uptime Kuma management socket.
- Added clickable monitor targets.
- Added settings and website creation windows that close the menu popover cleanly.
- Removed Keychain usage to avoid recurring macOS authorization prompts.
- Added local runtime logging under `~/Library/Logs/KumaBar/KumaBar.log`.
