# KumaBar

KumaBar is a lightweight native macOS menu bar client for a self-hosted
[Uptime Kuma](https://github.com/louislam/uptime-kuma) instance. It uses SwiftUI,
an AppKit status item, async networking, and local app settings storage. There is no embedded web
view or cross-platform runtime.

## Features

- Dense menu bar monitor list with failed monitors first
- Search-as-you-type filtering
- 30, 60, 120, or 300 second refresh intervals
- UP-to-DOWN and DOWN-to-UP notifications without repeated outage alerts
- Detail popover with status, response time, sampled check time, SSL expiry, and target
- Clickable detail targets and a compact in-app website monitor creation form
- Local credentials storage without recurring macOS Keychain prompts
- Dashboard shortcut and optional launch at login

## Requirements

- macOS 14 or later
- Xcode 16 or the Swift 6 toolchain

## Build

Build and run the executable during development:

```sh
swift run KumaBar
```

Build a signed local `.app` bundle:

```sh
./Scripts/build_app.sh
open .build/KumaBar.app
```

Create an installable disk image:

```sh
./Scripts/create_dmg.sh
```

The DMG is written to `.build/KumaBar.dmg`. The build script generates the
`.icns` icon asset from `Scripts/generate_icon.swift` on its first run.

## Configuration

Open KumaBar settings from the gear icon and enter:

```text
Uptime Kuma URL: <INSERT_URL_HERE>
API Key:         <INSERT_API_KEY_HERE>
```

The URL should be the root of the Kuma installation, for example:
`https://status.example.com`.

KumaBar supports plain `http://` URLs for self-hosted servers, including IP
addresses on private networks. Prefer HTTPS whenever possible because API keys
sent over HTTP are not encrypted in transit.

Generate an API key in Uptime Kuma under **Settings > API Keys**. KumaBar uses
the supported Prometheus `/metrics` endpoint because Uptime Kuma API keys are
designed for that endpoint. Username and password authentication are available
as a fallback for installations where API keys are not enabled.

See [Docs/SAMPLE_CONFIGURATION.md](Docs/SAMPLE_CONFIGURATION.md) for API key,
password fallback, reverse proxy, and validation examples.

## Credential Storage

KumaBar stores credentials in the current macOS user's local application
preferences to avoid recurring Keychain authorization prompts. These values are
not protected by macOS Keychain encryption. Use KumaBar only on a trusted Mac
user account and prefer an API key with the narrowest practical permissions.

## API Notes

The Prometheus endpoint exposes current monitor state, response time, monitor
labels, and SSL certificate days remaining. It does not expose a per-monitor
heartbeat timestamp, so KumaBar displays the time at which that monitor state
was sampled as **Last Check**.

KumaBar uses the lightweight `/metrics` endpoint for routine status refreshes.
The dashboard socket is opened only when saving a management login or adding a
website, then disconnected immediately.

## Architecture

```text
AppKit NSStatusItem + SwiftUI popover
      |
   AppModel
      |
MonitorProviding protocol
      |
KumaMetricsClient ---- /metrics

SettingsStore -------- UserDefaults
NotificationController
```

`MonitorProviding` keeps the data source independent from the interface. Future
providers can add multiple Kuma instances, push status, backup jobs, disk usage,
tags, grouping, or richer SSL alerts without reshaping the menu bar views.

## Adding Websites

Use the `+` button in the menu footer to add a standard HTTP website monitor.
Uptime Kuma API keys are read-only, so this action requires your Kuma username
and password once in **Settings > Management Login**. After verification,
KumaBar stores the returned Kuma login token in the local app settings, not the
management password. It reuses that token when adding websites and disconnects the
management socket immediately afterward. Accounts that require two-factor
authentication should add monitors in the Kuma dashboard.

## Test

```sh
swift test
```

## Distribution

`Scripts/create_dmg.sh` creates an ad-hoc signed DMG for local installation. For
public distribution, replace ad-hoc signing with a Developer ID Application
certificate and notarize the resulting DMG using your Apple Developer account.

Before publishing the repository, review
[Docs/OPEN_SOURCE_CHECKLIST.md](Docs/OPEN_SOURCE_CHECKLIST.md).
