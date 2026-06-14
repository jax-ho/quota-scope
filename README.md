# QuotaScope

QuotaScope is a macOS WidgetKit widget that monitors Codex quota from the
ChatGPT Codex usage API.

It shows:

- plan type from the Codex usage API
- 5-hour Codex limit remaining from `rate_limit.primary_window.used_percent`
- 7-day Codex limit remaining from `rate_limit.secondary_window.used_percent`
- token usage placeholders when the API does not provide token totals

## Why This Approach

Local Codex session JSONL can lag behind or disagree with the official Codex
usage page. QuotaScope therefore treats the API as the only widget data source.
It reads `~/.codex/auth.json` for the ChatGPT access token and account id, then
requests:

```text
https://chatgpt.com/backend-api/codex/usage
```

If the API is unavailable, the widget may use a short-lived API response cache.
Without fresh or cached API data, quota values display as `--` instead of
falling back to local session logs.

## Build And Install

Build the host app and embedded WidgetKit extension:

```sh
scripts/build-app.sh
```

Install it into `~/Applications`, register it with LaunchServices, and open the
host app once so macOS can discover the embedded widget extension:

```sh
scripts/install-app.sh
```

Then Control-click the desktop wallpaper, choose **Edit Widgets**, search for
**QuotaScope**, and drag the widget to the desktop.

Run the core parser and formatter tests:

```sh
swift test
```

## Distribution

QuotaScope ships outside the Mac App Store through GitHub Releases. The release
channel builds a Release app, creates a DMG, and uploads the DMG plus
`SHA256SUMS`. By default this is a free unsigned release that does not require
an Apple Developer Program membership. A Developer ID signed and notarized
release path is available later if Apple credentials are configured.

See [docs/release.md](docs/release.md) for local release commands, GitHub
Actions distribution modes, and troubleshooting.

The SwiftPM package is intentionally only the testable core library. The actual
macOS widget lives in `CodexWatcher.xcodeproj` as a host app plus
`CodexWatcherWidgetExtension.appex`.

## Notes

- WidgetKit controls the real refresh cadence. The widget asks for a new
  timeline roughly every 1 minute, but macOS may adjust that schedule.
- The WidgetKit extension is sandboxed so macOS will register it as a real
  widget. Its entitlements allow network access and read-only access to
  `~/.codex/` for `auth.json`.
- Codex stores limit data as used percentages; the widget displays remaining
  percentages (`100 - used_percent`) so the number means quota left.
- Token totals remain placeholders unless the Codex usage API starts returning
  token totals that QuotaScope can decode.
