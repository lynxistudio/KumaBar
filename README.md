# KumaBar

[![Download](https://img.shields.io/badge/Download-v1.3.1-blue?style=flat-square&logo=github)](https://github.com/lynxistudio/KumaBar/releases/latest)
[![Platform](https://img.shields.io/badge/macOS-14.0%2B-lightgrey?style=flat-square&logo=apple)](https://github.com/lynxistudio/KumaBar)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange?style=flat-square&logo=swift)](https://swift.org)

A native macOS menu bar client for [Uptime Kuma](https://github.com/louislam/uptime-kuma). Monitor all
your services at a glance — no browser, no web view, just a clean menu bar popover. Failed monitors
float to the top with a red badge count so you see problems instantly.

> **KumaBar lives in your menu bar.** Click the icon to see every monitor's status,
> response time, and SSL expiry. Search, filter, and even add new monitors without
> opening a browser.

## Quick Install

1. Download the latest `KumaBar-*.zip` from [Releases](https://github.com/lynxistudio/KumaBar/releases/latest)
2. Unzip and drag `KumaBar.app` into your `/Applications` folder
3. Launch KumaBar — it will appear in your menu bar
4. Open **Settings** (gear icon) and enter your Uptime Kuma URL + API Key

> **Note:** macOS may show a security warning on first launch because the app is not
> notarized. Right-click the app in Finder and select **Open** to proceed.

## Screenshots

*Screenshots coming soon. For now, launch the app to see the menu bar popover
with status dots, search, and detail popover.*

## Features

- **Menu bar monitor list** — failed monitors first with red badge count
- **Search-as-you-type** — filter monitors instantly by name
- **Adjustable refresh** — 30, 60, 120, or 300 second intervals
- **Wake recovery** — reconnect automatically after sleep and show stale-data warnings
- **Smart notifications** — UP→DOWN and DOWN→UP alerts, no repeated outage spam
- **Detail popover** — status, response time, check time, SSL expiry, clickable target
- **Add websites** — create HTTP monitors from inside the menu bar popover
- **Local credentials** — stored in app preferences, no recurring Keychain prompts
- **Dashboard shortcut** — open the full Uptime Kuma dashboard in your browser
- **Launch at login** — optional auto-start

## Configuration

Open KumaBar settings from the gear icon:

| Field | Description |
|-------|-------------|
| **Uptime Kuma URL** | Root URL of your Kuma instance, e.g. `https://status.example.com` |
| **API Key** | Create in Uptime Kuma under **Settings > API Keys**. KumaBar uses the Prometheus `/metrics` endpoint |

KumaBar supports plain `http://` for private-network servers. Prefer HTTPS
whenever possible — API keys sent over HTTP are not encrypted in transit.

For password fallback, reverse proxy, and validation examples, see
[Docs/SAMPLE_CONFIGURATION.md](Docs/SAMPLE_CONFIGURATION.md).

## Requirements

- macOS 14.0 (Sonoma) or later
- A self-hosted [Uptime Kuma](https://github.com/louislam/uptime-kuma) instance

## Build from Source

```bash
swift run KumaBar
```

Build a signed `.app` bundle:

```bash
./Scripts/build_app.sh
open .build/KumaBar.app
```

Create a disk image for distribution:

```bash
./Scripts/create_dmg.sh
```

The build script generates the `.icns` icon from `Scripts/generate_icon.swift`
on first run.

## Architecture

```
AppKit NSStatusItem + SwiftUI popover
        │
     AppModel
        │
MonitorProviding protocol
        │
KumaMetricsClient ──── /metrics
SettingsStore ──────── UserDefaults
NotificationController
```

`MonitorProviding` decouples the data source from the UI. Future providers can
add multi-instance support, push status, disk usage, or richer alerts without
changing the menu bar views.

## Project Structure

```
KumaBar/
├── Sources/KumaBar/          # App source code
│   ├── KumaBarApp.swift      # SwiftUI app entry
│   ├── AppDelegate.swift     # NSApplicationDelegate
│   ├── AppModel.swift        # Central state + polling
│   ├── StatusBarController.swift  # NSStatusItem management
│   ├── MenuContentView.swift      # Main menu bar popover
│   ├── MonitorDetailView.swift    # Per-monitor detail popover
│   ├── PreferencesView.swift      # Settings window
│   ├── AddWebsiteView.swift       # In-app monitor creation
│   ├── KumaMetricsClient.swift    # Prometheus /metrics parser
│   ├── KumaManagementClient.swift # Uptime Kuma socket client
│   ├── SettingsStore.swift        # UserDefaults wrapper
│   ├── Models.swift               # Data models
│   ├── NotificationController.swift
│   ├── MenuBarIconRenderer.swift
│   ├── RuntimeLog.swift
│   └── AuxiliaryWindowController.swift
├── Tests/KumaBarTests/       # Unit tests
├── Config/Info.plist
├── Assets/AppIcon.icns
├── Scripts/                  # Build & DMG scripts
├── Docs/                     # Additional documentation
└── Package.swift
```

## License

MIT — see [LICENSE](LICENSE).
