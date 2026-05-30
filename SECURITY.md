# Security Policy

## Reporting a Vulnerability

Do not publish security vulnerabilities, credentials, private monitor URLs, or
login tokens in a public issue. Use a private GitHub security advisory after the
repository is published.

## Credential Storage

KumaBar stores credentials in the current macOS user's local application
preferences to avoid recurring Keychain authorization prompts. This is a
usability tradeoff: the values are not protected by macOS Keychain encryption.

Use KumaBar only on a trusted Mac user account. Prefer HTTPS for the Uptime Kuma
URL, especially when using an API key or password across a network.
