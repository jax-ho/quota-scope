# QuotaScope

QuotaScope is a macOS WidgetKit widget that monitors Codex quota from the
ChatGPT Codex usage API and local Codex token events.

It shows:

- plan type from the Codex usage API
- 5-hour Codex limit remaining from `rate_limit.primary_window.used_percent`
- 7-day Codex limit remaining from `rate_limit.secondary_window.used_percent`
- today's token total from local Codex `token_count` events
- historical last-7-days token totals from Codex `account/usage/read`, with
  local token events as the fallback when that API is unavailable

## Why This Approach

Codex writes local session events as JSONL under `~/.codex/sessions` and
`~/.codex/archived_sessions`. Those `token_count` events are the most useful
source for today's token total because the account token-activity API can lag
while Codex is actively used.

QuotaScope reads `~/.codex/auth.json` for the ChatGPT access token and account
id, then requests rate limits from:

```text
https://chatgpt.com/backend-api/wham/usage
https://chatgpt.com/backend-api/codex/usage
```

For historical token totals, QuotaScope asks the Codex app-server
`account/usage/read` API for `dailyUsageBuckets`. When those buckets are
available, historical days use the API values, but today's bucket is always
replaced with the local token total. If the historical API is unavailable,
QuotaScope falls back to local session events for the last-7-days chart. If the
rate-limit API is unavailable, remaining quota values display as `--` unless a
short-lived QuotaScope API response cache is available.

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
  `~/.codex/` for `auth.json` and local session events.
- Codex stores limit data as used percentages; the widget displays remaining
  percentages (`100 - used_percent`) so the number means quota left.
- Today's token total comes from local Codex session JSONL. Historical daily
  totals prefer Codex app-server `account/usage/read` daily buckets and fall
  back to local session JSONL when the API is unavailable.
