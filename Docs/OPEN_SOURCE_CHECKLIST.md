# Open Source Checklist

Complete these items before publishing KumaBar on GitHub.

## Required

- Choose and add a `LICENSE` file. MIT is a common permissive choice, but the
  project owner should make this decision.
- Create a GitHub repository and push only the source files.
- Confirm that no real Kuma URL, API key, username, password, or login token is
  present in the repository.
- Review `SECURITY.md` and enable GitHub private vulnerability reporting.
- Build and test from a fresh clone.

## Release Preparation

- Build the app with `./Scripts/build_app.sh`.
- For public distribution, sign with a Developer ID Application certificate.
- Notarize the app or DMG before sharing it with users.
- Attach release archives to a GitHub Release instead of committing them.

## Future Improvement

Local preference storage avoids repeated Keychain prompts but does not provide
Keychain encryption. Consider adding an optional secure-storage mode before a
broader public release.
