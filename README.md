# QuotaScope

QuotaScope is a macOS WidgetKit widget that monitors Codex quota and token
activity from local Codex session logs on this Mac.

It shows:

- plan type from the latest local `token_count` rate-limit payload, when
  available
- 5-hour and 7-day remaining quota from local `rate_limits` used percentages
- today, this week, and last-7-days token totals from local `token_count` events

## Data Scope

The host app and WidgetKit extension use local data only. They do not call the
Codex usage API or the Codex app-server `account/usage/read` endpoint for the
visible numbers.

QuotaScope reads `.jsonl` session files under:

```text
~/.codex/sessions
~/.codex/archived_sessions
```

The token totals therefore cover Codex activity recorded on this Mac. Activity
from another machine is not included unless its session logs are present here.
Day and week buckets use the Mac's current local time zone.

## Why This Approach

QuotaScope intentionally does not use service-side daily token buckets for the
visible token totals. API-provided daily buckets can be aggregated on server
time boundaries that do not line up with the local day, so the widget keeps one
consistent local-data scope for today, this week, and the last-7-days chart.

Remaining quota is also read from local `token_count` events when Codex emits a
`rate_limits` payload. If no local rate-limit payload is available, QuotaScope
shows `--` for those quota values instead of filling them from an API.

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
  widget. Its entitlements allow read-only access to `~/.codex/` for local
  session events.
- Codex stores limit data as used percentages; the widget displays remaining
  percentages (`100 - used_percent`) so the number means quota left.
- The parser uses `last_token_usage` from each local `token_count` event for
  bucketed totals.
