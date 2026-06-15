# QuotaScope WidgetKit Design Assets

This folder contains historical design assets and fallback generators for the
QuotaScope macOS WidgetKit layout. The current SwiftUI implementation is the
source of truth for behavior and copy.

The Figma MCP connector returned a Starter plan tool-call limit before a new
file could be created or the app icon source could be inspected. The generator
therefore uses the requested fallback path: a temporary, geometric QuotaScope
icon placeholder with a native macOS app-icon feel.

## File

- `quota_scope_widgetkit_figma_plugin.js`
- `generate_quota_scope_preview.js`
- `quota_scope_widgetkit_preview.svg`

## What It Creates

- `QuotaScope / Widget / Small`
- `QuotaScope / Widget / Medium`
- `QuotaScope / Widget / Large`
- `QuotaScope / Design System`

The generated frames explore three widget sizes:

- Small: glanceable quotas, today token total, compact M/C/O breakdown.
- Medium: two-column quota and token summary for everyday desktop use.
- Large: structured dashboard with quota overview, today/week breakdowns, and
  status details.

## Running In Figma

Create a temporary Figma plugin and use
`quota_scope_widgetkit_figma_plugin.js` as the plugin `main` code. Running it
creates a new page named `QuotaScope WidgetKit Widgets` and lays out all frames.

The script prefers SF Pro fonts when available and falls back to Inter or the
first available font. The visual system is intentionally SwiftUI-friendly:
rounded widget backgrounds, small cards, capsule bars, status chips, and simple
section rows.

## Preview Locally

Regenerate the standalone SVG preview with:

```sh
node design/generate_quota_scope_preview.js
```

Open `quota_scope_widgetkit_preview.svg` to inspect the full design board. It is
not a replacement for the SwiftUI widget or a guarantee that every label still
matches the app; use it as visual reference.

## Design Tokens

- Dark material background, not pure black.
- Muted cool brand accent with cyan and indigo quota colors.
- Restrained token breakdown colors: input miss, input cache, output.
- Widget radius: 24-28.
- Card radius: 10-12.
- Compact spacing: 4 / 8 / 12 / 16 / 18.
- Use tabular numbers in SwiftUI for quota and token values.
