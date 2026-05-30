# Sample Configuration Guide

## Preferred: API Key

1. Open your Uptime Kuma dashboard.
2. Go to **Settings > API Keys**.
3. Generate a key and keep a secure copy. Uptime Kuma only shows it once.
4. Open KumaBar settings from the gear icon.
5. Select **API Key** and enter:

```text
Uptime Kuma URL: <INSERT_URL_HERE>
API Key:         <INSERT_API_KEY_HERE>
```

For example:

```text
Uptime Kuma URL: https://status.example.com
API Key:         uk_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

Use the root Uptime Kuma URL. KumaBar adds `/metrics` automatically.

KumaBar accepts plain `http://` URLs for self-hosted servers. Prefer HTTPS when
possible: API keys sent over HTTP are not encrypted while traveling between
KumaBar and the server.

## Fallback: Username and Password

Select **Username & Password** in KumaBar settings and enter your Uptime Kuma
account credentials.

This fallback only works on Uptime Kuma installations that have never enabled
API keys. Uptime Kuma permanently disables username/password access to the
Prometheus metrics endpoint as soon as the first API key is added.

## Reverse Proxy

If Uptime Kuma runs behind a reverse proxy, make sure the `/metrics` path is
forwarded to the Kuma server and is not replaced by a proxy-specific login page.

You can validate API key access before configuring KumaBar:

```sh
curl -u ":<INSERT_API_KEY_HERE>" "<INSERT_URL_HERE>/metrics"
```

The response should contain metrics such as `monitor_status` and
`monitor_response_time`.

## Local Credential Storage

KumaBar stores its URL, API key or metrics password, refresh interval,
launch-at-login state, notification preference, and management login token in
the current macOS user's local application preferences. This avoids recurring
macOS Keychain authorization prompts, but the stored values are not protected by
Keychain encryption. Use KumaBar only from a trusted Mac user account.

The password entered under **Management Login** is used once to request a Kuma
login token and is not retained after verification.
