# Contributing to KumaBar

Thanks for helping improve KumaBar.

## Development Setup

Requirements:

- macOS 14 or later
- Xcode 16 or a Swift 6 toolchain

Run the test suite:

```sh
swift test
```

Build a local app bundle:

```sh
./Scripts/build_app.sh
```

## Pull Requests

- Keep changes focused and consistent with the compact menu bar interface.
- Add or update tests for behavior changes.
- Do not commit `.build`, local preferences, logs, credentials, or release archives.
- Never include a real Uptime Kuma URL, API key, username, password, or login token.

## Reporting Bugs

Include the KumaBar version, macOS version, Uptime Kuma version, and the steps
needed to reproduce the issue. Remove credentials and private monitor URLs from
screenshots and logs before sharing them.
