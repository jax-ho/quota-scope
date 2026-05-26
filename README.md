# Codex Watcher

Codex Watcher is a macOS WidgetKit widget that monitors local Codex usage from
`~/.codex/sessions` and `~/.codex/archived_sessions`.

It shows:

- 5-hour Codex limit remaining from `rate_limits.primary.used_percent`
- 7-day Codex limit remaining from `rate_limits.secondary.used_percent`
- today's local token usage, split into input cache miss, input cache hit, and output
- current ISO week local token usage, split into input cache miss, input cache hit, and output

## Why This Approach

Codex writes local session events as JSONL. `event_msg` records with
`payload.type == "token_count"` include both token counters and rate-limit
metadata:

- `total_token_usage`
- `last_token_usage`
- `rate_limits.primary`
- `rate_limits.secondary`

That gives the app a local, read-only data source. It does not read
`~/.codex/auth.json` or make network requests.

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
**Codex Watcher**, and drag the widget to the desktop.

Run the core parser and formatter tests:

```sh
swift test
```

The SwiftPM package is intentionally only the testable core library. The actual
macOS widget lives in `CodexWatcher.xcodeproj` as a host app plus
`CodexWatcherWidgetExtension.appex`.

## Notes

- WidgetKit controls the real refresh cadence. The widget asks for a new
  timeline roughly every 1 minute, but macOS may adjust that schedule.
- The widget scans recent JSONL files from the last 8 days so it can
  calculate today's token total and the current ISO week total.
- Input cache miss is calculated as `input_tokens - cached_input_tokens`;
  input cache hit uses `cached_input_tokens`; output uses `output_tokens`.
- Parsed token events are cached by file size and modification time. Repeated
  refreshes reuse the cache, and growing log files are read only from the last
  cached byte offset.
- The WidgetKit extension is sandboxed so macOS will register it as a real
  widget. Its entitlements allow read-only access to `~/.codex/`.
- Very large non-token event lines are skipped with a streaming reader, so the
  widget does not load full historical session files into memory.
- Codex stores limit data as used percentages; the widget displays remaining
  percentages (`100 - used_percent`) so the number means quota left.
- The limit percentages come from the latest local Codex `token_count` event.
  If Codex has not written a recent event yet, the display may lag behind the
  official Codex usage page.
