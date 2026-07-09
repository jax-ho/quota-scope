# QuotaScope

QuotaScope is a small macOS widget for keeping an eye on your local Codex quota
and token usage.

It shows the latest plan label, remaining 5-hour and 7-day quota, today's token
usage, this week's token usage, and a last-7-days activity chart. The numbers
come from Codex session logs on this Mac, so it is meant to answer: "How much
have I used from here?"

## Install

1. Download `QuotaScope-<version>.dmg` from the latest GitHub Release.
2. Open the DMG and drag `QuotaScope.app` to Applications.
3. Open `QuotaScope.app` once. This lets macOS discover the bundled widget.
4. If macOS blocks the unsigned app, Control-click `QuotaScope.app`, choose
   **Open**, then confirm in the system prompt.

QuotaScope supports macOS 13 Ventura and later.

## Add The Widget

On macOS 13:

1. Open Notification Center.
2. Click **Edit Widgets**.
3. Search for **QuotaScope**.
4. Add the widget to Notification Center.

On macOS 14 or later:

1. Control-click the desktop wallpaper.
2. Choose **Edit Widgets**.
3. Search for **QuotaScope**.
4. Drag the widget to the desktop, or add it to Notification Center.

If the widget does not appear right away, open `QuotaScope.app` once more and
try Edit Widgets again.

## Read The Numbers

- **5h** shows remaining quota for the current 5-hour Codex window.
- **7d** shows remaining quota for the current 7-day Codex window.
- **Today** shows token usage for the current local day.
- **Week** shows token usage for the current local week.
- **M / C / O** break token usage into input miss, cached input, and output.

QuotaScope displays remaining quota as `100 - used_percent`, matching the
rate-limit payloads Codex records locally. If Codex has not written a recent
rate-limit payload, quota fields show `--` until new data is available.

## Data Scope

QuotaScope reads local Codex session files from:

```text
~/.codex/sessions
~/.codex/archived_sessions
```

It does not call the Codex usage API for the visible numbers. Activity from
another Mac is not included unless those session logs are also present here.
Day and week totals use this Mac's current local time zone.

## Refreshing

The widget asks WidgetKit for fresh data roughly once a minute, but macOS may
adjust the actual refresh schedule. To nudge it manually, open `QuotaScope.app`
and click **Reload Widget**.

## Troubleshooting

If the widget is empty, use Codex normally for a bit, then reload the widget.
QuotaScope can only show data after Codex has written local session events.

If the quota fields show `--`, Codex has not recently written rate-limit data
on this Mac. Token totals can still appear because they come from local
`token_count` events.

If the app cannot be opened after download, it is probably macOS Gatekeeper
blocking an unsigned release. Control-click the app, choose **Open**, or approve
it in System Settings > Privacy & Security.
