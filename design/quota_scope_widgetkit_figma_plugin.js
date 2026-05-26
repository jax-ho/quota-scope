/*
QuotaScope WidgetKit Figma generator

Run this as the main code of a temporary Figma plugin when the Figma MCP
connector is unavailable. It creates:
- QuotaScope / Widget / Small
- QuotaScope / Widget / Medium
- QuotaScope / Widget / Large
- QuotaScope / Design System

The visual direction is intentionally quiet and native-macOS leaning: dark
material surfaces, compact stat rows, capsule progress bars, restrained cool
accent colors, and SwiftUI-friendly layout primitives.
*/

const PAGE_NAME = "QuotaScope WidgetKit Widgets";

const colors = {
  canvas: hex("0D1116"),
  widgetBg: hex("171B21"),
  widgetBgAlt: hex("1B2027"),
  surface: hex("222833"),
  surfaceAlt: hex("262D38"),
  border: hex("FFFFFF"),
  text: hex("F3F6FA"),
  textSecondary: hex("B8C1CF"),
  textMuted: hex("7E8A9B"),
  brand: hex("6EA8FF"),
  cyan: hex("6DD6DD"),
  indigo: hex("9AA7FF"),
  miss: hex("78BFFB"),
  cache: hex("84D9AA"),
  output: hex("B5A2FF"),
  success: hex("74D99F"),
  track: hex("303845"),
  trackSoft: hex("2A313D")
};

let createdNodeIds = [];
let fonts;

function hex(value) {
  const int = parseInt(value, 16);
  return {
    r: ((int >> 16) & 255) / 255,
    g: ((int >> 8) & 255) / 255,
    b: (int & 255) / 255
  };
}

function paint(color, opacity = 1) {
  return [{ type: "SOLID", color, opacity }];
}

function add(parent, node) {
  parent.appendChild(node);
  createdNodeIds.push(node.id);
  return node;
}

function createFrame(parent, name, x, y, width, height, options = {}) {
  const node = figma.createFrame();
  node.name = name;
  add(parent, node);
  node.x = x;
  node.y = y;
  node.resize(width, height);
  node.clipsContent = options.clipsContent ?? true;
  node.cornerRadius = options.radius ?? 0;
  node.fills = paint(options.fill ?? colors.surface, options.opacity ?? 1);
  if (options.stroke) {
    node.strokes = paint(options.stroke, options.strokeOpacity ?? 1);
    node.strokeWeight = options.strokeWeight ?? 1;
  } else {
    node.strokes = [];
  }
  if (options.effects) node.effects = options.effects;
  return node;
}

function createRect(parent, name, x, y, width, height, options = {}) {
  const node = figma.createRectangle();
  node.name = name;
  add(parent, node);
  node.x = x;
  node.y = y;
  node.resize(width, height);
  node.cornerRadius = options.radius ?? 0;
  node.fills = options.fill === null ? [] : paint(options.fill ?? colors.surface, options.opacity ?? 1);
  if (options.stroke) {
    node.strokes = paint(options.stroke, options.strokeOpacity ?? 1);
    node.strokeWeight = options.strokeWeight ?? 1;
  } else {
    node.strokes = [];
  }
  if (options.rotation) node.rotation = options.rotation;
  return node;
}

function createEllipse(parent, name, x, y, width, height, options = {}) {
  const node = figma.createEllipse();
  node.name = name;
  add(parent, node);
  node.x = x;
  node.y = y;
  node.resize(width, height);
  node.fills = options.fill === null ? [] : paint(options.fill ?? colors.surface, options.opacity ?? 1);
  if (options.stroke) {
    node.strokes = paint(options.stroke, options.strokeOpacity ?? 1);
    node.strokeWeight = options.strokeWeight ?? 1.5;
  } else {
    node.strokes = [];
  }
  return node;
}

function createText(parent, name, value, x, y, width, size, weight, color, options = {}) {
  const node = figma.createText();
  node.name = name;
  add(parent, node);
  node.x = x;
  node.y = y;
  node.fontName = fonts[weight] ?? fonts.regular;
  node.fontSize = size;
  node.lineHeight = { unit: "PIXELS", value: options.lineHeight ?? Math.round(size * 1.25) };
  node.letterSpacing = { unit: "PERCENT", value: 0 };
  node.fills = paint(color);
  node.textAutoResize = "HEIGHT";
  node.characters = value;
  node.resize(width, Math.max(size + 4, node.height));
  if (options.align) node.textAlignHorizontal = options.align;
  return node;
}

function backgroundEffects() {
  return [
    {
      type: "DROP_SHADOW",
      color: { r: 0, g: 0, b: 0, a: 0.24 },
      offset: { x: 0, y: 18 },
      radius: 30,
      spread: -10,
      visible: true,
      blendMode: "NORMAL"
    },
    {
      type: "INNER_SHADOW",
      color: { r: 1, g: 1, b: 1, a: 0.05 },
      offset: { x: 0, y: 1 },
      radius: 0,
      spread: 0,
      visible: true,
      blendMode: "NORMAL"
    }
  ];
}

function makeWidget(parent, name, x, y, width, height) {
  return createFrame(parent, name, x, y, width, height, {
    fill: colors.widgetBg,
    radius: width <= 170 ? 24 : 28,
    stroke: colors.border,
    strokeOpacity: 0.08,
    effects: backgroundEffects()
  });
}

function tempIcon(parent, x, y, size) {
  const icon = createFrame(parent, "AppIdentity/TemporaryQuotaScopeIcon", x, y, size, size, {
    fill: colors.surfaceAlt,
    radius: Math.round(size * 0.24),
    stroke: colors.border,
    strokeOpacity: 0.12
  });
  icon.clipsContent = true;
  createRect(icon, "IconBase/BrandWash", 0, 0, size, size, {
    fill: colors.brand,
    opacity: 0.16,
    radius: Math.round(size * 0.24)
  });
  createEllipse(icon, "IconGlyph/ScopeRing", size * 0.22, size * 0.2, size * 0.43, size * 0.43, {
    fill: null,
    stroke: colors.cyan,
    strokeWeight: Math.max(1.2, size * 0.075)
  });
  createRect(icon, "IconGlyph/ScopeHandle", size * 0.57, size * 0.6, size * 0.28, size * 0.075, {
    fill: colors.indigo,
    radius: size * 0.05,
    rotation: -45
  });
  createRect(icon, "IconGlyph/QuotaMark", size * 0.19, size * 0.72, size * 0.5, size * 0.06, {
    fill: colors.brand,
    radius: size * 0.04,
    opacity: 0.8
  });
  return icon;
}

function planPill(parent, x, y, width, compact = false) {
  createRect(parent, "PlanPill/Background", x, y, width, 18, {
    fill: colors.brand,
    opacity: 0.12,
    radius: 9,
    stroke: colors.brand,
    strokeOpacity: 0.22
  });
  createText(parent, "PlanPill/Text", compact ? "prolite" : "plan prolite", x + 8, y + 3, width - 16, 10, "medium", colors.brand, {
    lineHeight: 12,
    align: "CENTER"
  });
}

function quotaProgress(parent, name, x, y, width, ratio, color) {
  createRect(parent, `${name}/QuotaProgressBar/Track`, x, y, width, 5, {
    fill: colors.track,
    radius: 3
  });
  createRect(parent, `${name}/QuotaProgressBar/Fill`, x, y, Math.max(5, width * ratio), 5, {
    fill: color,
    radius: 3
  });
}

function divider(parent, x, y, width, height, vertical = false) {
  createRect(parent, vertical ? "Divider/Vertical" : "Divider/Horizontal", x, y, width, height, {
    fill: colors.border,
    opacity: 0.08,
    radius: 1
  });
}

function quotaCard(parent, name, x, y, width, height, label, value, reset, ratio, accent) {
  const card = createFrame(parent, `QuotaCard/${name}`, x, y, width, height, {
    fill: colors.surface,
    radius: 10,
    stroke: colors.border,
    strokeOpacity: 0.06
  });
  const isCompact = height <= 50;
  createText(card, "QuotaCard/Label", label, 10, 8, width - 20, 10, "medium", colors.textMuted, { lineHeight: 12 });
  createText(card, "QuotaCard/Value", value, 10, isCompact ? 21 : 20, width - 20, isCompact ? 13 : 14, "semibold", colors.text, {
    lineHeight: isCompact ? 15 : 17
  });
  createText(card, "QuotaCard/Reset", reset, width - 86, 9, 76, 10, "regular", colors.textMuted, {
    lineHeight: 12,
    align: "RIGHT"
  });
  quotaProgress(card, name, 10, isCompact ? height - 8 : height - 12, width - 20, ratio, accent);
  return card;
}

function tokenRow(parent, name, x, y, label, value, color, width = 124) {
  createEllipse(parent, `TokenBreakdownRow/${name}/Dot`, x, y + 4, 6, 6, { fill: color });
  createText(parent, `TokenBreakdownRow/${name}/Label`, label, x + 11, y, width - 52, 10, "regular", colors.textMuted, {
    lineHeight: 12
  });
  createText(parent, `TokenBreakdownRow/${name}/Value`, value, x + width - 42, y, 42, 10, "medium", colors.textSecondary, {
    lineHeight: 12,
    align: "RIGHT"
  });
}

function statusChip(parent, name, x, y, width, label, color) {
  createRect(parent, `StatusChip/${name}/Background`, x, y, width, 22, {
    fill: colors.surface,
    radius: 11,
    stroke: colors.border,
    strokeOpacity: 0.07
  });
  createEllipse(parent, `StatusChip/${name}/Dot`, x + 9, y + 8, 6, 6, { fill: color });
  createText(parent, `StatusChip/${name}/Text`, label, x + 20, y + 5, width - 28, 10, "medium", colors.textSecondary, {
    lineHeight: 12
  });
}

function createSmallWidget(parent) {
  tempIcon(parent, 14, 12, 22);
  createText(parent, "Header/AppIdentity/AppName", "QuotaScope", 42, 12, 78, 11, "semibold", colors.text, { lineHeight: 13 });
  createText(parent, "Header/AppIdentity/Plan", "plan prolite", 42, 27, 78, 10, "regular", colors.textMuted, { lineHeight: 12 });

  createText(parent, "QuotaSummary/5h/Label", "5h", 14, 50, 22, 11, "medium", colors.textSecondary, { lineHeight: 13 });
  createText(parent, "QuotaSummary/5h/Value", "62%", 114, 50, 32, 11, "semibold", colors.text, {
    lineHeight: 13,
    align: "RIGHT"
  });
  quotaProgress(parent, "QuotaSummary/5h", 14, 68, 132, 0.62, colors.cyan);

  createText(parent, "QuotaSummary/7d/Label", "7d", 14, 79, 22, 11, "medium", colors.textSecondary, { lineHeight: 13 });
  createText(parent, "QuotaSummary/7d/Value", "81%", 114, 79, 32, 11, "semibold", colors.text, {
    lineHeight: 13,
    align: "RIGHT"
  });
  quotaProgress(parent, "QuotaSummary/7d", 14, 97, 132, 0.81, colors.indigo);

  divider(parent, 14, 111, 132, 1);
  createText(parent, "TokenSummary/Label", "Today", 14, 119, 42, 10, "medium", colors.textMuted, { lineHeight: 12 });
  createText(parent, "TokenSummary/Value", "128.4K", 58, 116, 88, 18, "semibold", colors.text, {
    lineHeight: 21,
    align: "RIGHT"
  });
  createText(parent, "TokenSummary/BreakdownCompact", "M38.2K  C91.6K  O26.4K", 14, 140, 132, 8.5, "regular", colors.textMuted, {
    lineHeight: 10,
    align: "CENTER"
  });
}

function createMediumWidget(parent) {
  tempIcon(parent, 16, 14, 22);
  createText(parent, "Header/AppIdentity/AppName", "QuotaScope", 46, 14, 112, 12, "semibold", colors.text, { lineHeight: 15 });
  createText(parent, "Header/AppIdentity/Subtitle", "quota and tokens", 46, 29, 112, 9.5, "regular", colors.textMuted, {
    lineHeight: 11
  });
  planPill(parent, 248, 15, 76, false);

  quotaCard(parent, "5h Limit", 14, 50, 148, 45, "5h limit", "62% remaining", "until 16:20", 0.62, colors.cyan);
  quotaCard(parent, "7d Limit", 14, 101, 148, 45, "7d limit", "81% remaining", "05/31 15:50", 0.81, colors.indigo);
  divider(parent, 176, 52, 1, 94, true);

  createText(parent, "TokenSummary/Today/Label", "Today", 192, 52, 58, 10, "medium", colors.textMuted, { lineHeight: 12 });
  createText(parent, "TokenSummary/Today/Value", "128.4K", 252, 49, 72, 18, "semibold", colors.text, {
    lineHeight: 21,
    align: "RIGHT"
  });
  createText(parent, "TokenSummary/Week/Label", "Week", 192, 75, 58, 10, "medium", colors.textMuted, { lineHeight: 12 });
  createText(parent, "TokenSummary/Week/Value", "812.7K", 252, 72, 72, 18, "semibold", colors.textSecondary, {
    lineHeight: 21,
    align: "RIGHT"
  });

  divider(parent, 192, 98, 132, 1);
  tokenRow(parent, "InputMiss", 192, 108, "Input miss", "38.2K", colors.miss, 132);
  tokenRow(parent, "InputCache", 192, 123, "Input cache", "91.6K", colors.cache, 132);
  tokenRow(parent, "Output", 192, 138, "Output", "26.4K", colors.output, 132);
}

function sectionTitle(parent, value, x, y, width) {
  createText(parent, "SectionTitle", value, x, y, width, 10, "semibold", colors.textMuted, {
    lineHeight: 12
  });
}

function summaryCard(parent, name, x, y, width, label, value) {
  const card = createFrame(parent, `TokenSummary/${name}`, x, y, width, 48, {
    fill: colors.surface,
    radius: 11,
    stroke: colors.border,
    strokeOpacity: 0.06
  });
  createText(card, "TokenSummary/Label", label, 10, 8, width - 20, 10, "medium", colors.textMuted, { lineHeight: 12 });
  createText(card, "TokenSummary/Value", value, 10, 22, width - 20, 18, "semibold", colors.text, { lineHeight: 21 });
  return card;
}

function breakdownCard(parent, name, x, y, width, title, rows) {
  const card = createFrame(parent, `TokenBreakdownCard/${name}`, x, y, width, 64, {
    fill: colors.surface,
    radius: 11,
    stroke: colors.border,
    strokeOpacity: 0.06
  });
  createText(card, "TokenBreakdownCard/Title", title, 10, 8, width - 20, 10, "semibold", colors.textSecondary, {
    lineHeight: 12
  });
  rows.forEach((row, index) => tokenRow(card, row.name, 10, 24 + index * 13, row.label, row.value, row.color, width - 20));
  return card;
}

function miniTrend(parent, x, y, width) {
  const card = createFrame(parent, "MiniTrendPlaceholder", x, y, width, 54, {
    fill: colors.surface,
    radius: 12,
    stroke: colors.border,
    strokeOpacity: 0.06
  });
  createText(card, "MiniTrendPlaceholder/Title", "Usage trend", 10, 8, 92, 10, "semibold", colors.textSecondary, { lineHeight: 12 });
  createText(card, "MiniTrendPlaceholder/Hint", "future burn rate", width - 102, 8, 92, 10, "regular", colors.textMuted, {
    lineHeight: 12,
    align: "RIGHT"
  });
  const points = [
    [12, 38],
    [46, 33],
    [80, 36],
    [114, 25],
    [148, 29],
    [182, 20],
    [216, 24],
    [250, 17],
    [284, 21]
  ];
  for (let i = 0; i < points.length - 1; i += 1) {
    const [x1, y1] = points[i];
    const [x2, y2] = points[i + 1];
    const dx = x2 - x1;
    const dy = y2 - y1;
    const length = Math.sqrt(dx * dx + dy * dy);
    const line = createRect(card, "MiniTrendPlaceholder/SparklineSegment", x1, y1, length, 1.4, {
      fill: colors.cyan,
      opacity: 0.55,
      radius: 1
    });
    line.rotation = Math.atan2(dy, dx) * 180 / Math.PI;
  }
}

function miniTrendChip(parent, x, y, width) {
  const card = createFrame(parent, "MiniTrendPlaceholder", x, y, width, 22, {
    fill: colors.surface,
    radius: 11,
    stroke: colors.border,
    strokeOpacity: 0.07
  });
  createText(card, "MiniTrendPlaceholder/Title", "Burn rate", 9, 5, 48, 9.5, "medium", colors.textMuted, {
    lineHeight: 11
  });
  const points = [
    [58, 14],
    [66, 11],
    [74, 13],
    [82, 8],
    [90, 10],
    [98, 7]
  ];
  for (let i = 0; i < points.length - 1; i += 1) {
    const [x1, y1] = points[i];
    const [x2, y2] = points[i + 1];
    const dx = x2 - x1;
    const dy = y2 - y1;
    const length = Math.sqrt(dx * dx + dy * dy);
    const line = createRect(card, "MiniTrendPlaceholder/SparklineSegment", x1, y1, length, 1.2, {
      fill: colors.cyan,
      opacity: 0.55,
      radius: 1
    });
    line.rotation = Math.atan2(dy, dx) * 180 / Math.PI;
  }
}

function createLargeWidget(parent) {
  tempIcon(parent, 18, 16, 24);
  createText(parent, "Header/AppIdentity/AppName", "QuotaScope", 50, 15, 110, 13, "semibold", colors.text, { lineHeight: 16 });
  createText(parent, "Header/LastUpdated", "Last updated 12:42", 198, 18, 124, 10, "regular", colors.textMuted, {
    lineHeight: 12,
    align: "RIGHT"
  });
  planPill(parent, 50, 33, 82, false);

  sectionTitle(parent, "Quota Overview", 18, 61, 130);
  quotaCard(parent, "5h Limit", 18, 78, 146, 58, "5h limit", "62% remaining", "until 16:20", 0.62, colors.cyan);
  quotaCard(parent, "7d Limit", 176, 78, 146, 58, "7d limit", "81% remaining", "05/31 15:50", 0.81, colors.indigo);

  sectionTitle(parent, "Token Usage", 18, 151, 130);
  summaryCard(parent, "Today", 18, 168, 146, "Today", "128.4K tokens");
  summaryCard(parent, "Week", 176, 168, 146, "Week", "812.7K tokens");

  breakdownCard(parent, "Today", 18, 226, 146, "Today breakdown", [
    { name: "InputMiss", label: "Input miss", value: "38.2K", color: colors.miss },
    { name: "InputCache", label: "Input cache", value: "91.6K", color: colors.cache },
    { name: "Output", label: "Output", value: "26.4K", color: colors.output }
  ]);
  breakdownCard(parent, "Week", 176, 226, 146, "Week breakdown", [
    { name: "InputMiss", label: "Input miss", value: "214.8K", color: colors.miss },
    { name: "InputCache", label: "Input cache", value: "512.3K", color: colors.cache },
    { name: "Output", label: "Output", value: "85.6K", color: colors.output }
  ]);

  sectionTitle(parent, "System Status / Future", 18, 304, 160);
  statusChip(parent, "APIConnected", 18, 322, 92, "API Connected", colors.success);
  statusChip(parent, "CacheHealthy", 118, 322, 104, "Cache Healthy", colors.success);
  miniTrendChip(parent, 232, 322, 90);
}

function swatch(parent, name, x, y, color, label) {
  createRect(parent, `ColorToken/${name}/Swatch`, x, y, 18, 18, {
    fill: color,
    radius: 5,
    stroke: colors.border,
    strokeOpacity: 0.1
  });
  createText(parent, `ColorToken/${name}/Label`, label, x + 26, y + 3, 112, 10, "regular", colors.textSecondary, { lineHeight: 12 });
}

function createDesignSystem(parent) {
  createText(parent, "DesignSystem/Title", "QuotaScope Widget Design System", 22, 18, 300, 16, "semibold", colors.text, {
    lineHeight: 20
  });
  createText(parent, "DesignSystem/Subtitle", "SwiftUI-friendly tokens for WidgetKit desktop widgets", 22, 41, 330, 10, "regular", colors.textMuted, {
    lineHeight: 12
  });

  sectionTitle(parent, "Color tokens", 22, 72, 120);
  swatch(parent, "WidgetBackground", 22, 92, colors.widgetBg, "WidgetBackground");
  swatch(parent, "Surface", 22, 118, colors.surface, "Surface");
  swatch(parent, "Brand", 22, 144, colors.brand, "Brand");
  swatch(parent, "Quota5h", 22, 170, colors.cyan, "Quota5h");
  swatch(parent, "Quota7d", 22, 196, colors.indigo, "Quota7d");
  swatch(parent, "InputMiss", 186, 92, colors.miss, "Input miss");
  swatch(parent, "InputCache", 186, 118, colors.cache, "Input cache");
  swatch(parent, "Output", 186, 144, colors.output, "Output");
  swatch(parent, "Success", 186, 170, colors.success, "Success");
  swatch(parent, "Divider", 186, 196, colors.border, "Divider 8%");

  sectionTitle(parent, "Type scale", 22, 234, 120);
  createText(parent, "Typography/Title", "Title 16 Semibold", 22, 254, 160, 16, "semibold", colors.text, { lineHeight: 20 });
  createText(parent, "Typography/Metric", "Metric 20 Semibold", 22, 280, 180, 20, "semibold", colors.text, { lineHeight: 24 });
  createText(parent, "Typography/Caption", "Caption 10 Regular", 22, 312, 160, 10, "regular", colors.textMuted, { lineHeight: 12 });
  createText(parent, "Typography/Note", "Use tabular numbers for quota and token values.", 22, 332, 230, 10, "regular", colors.textMuted, {
    lineHeight: 12
  });

  sectionTitle(parent, "Radius and spacing", 282, 234, 128);
  createText(parent, "Radius/Values", "Widget 24-28\nCard 10-12\nPill 999", 282, 254, 118, 10, "regular", colors.textSecondary, {
    lineHeight: 15
  });
  createText(parent, "Spacing/Values", "4 / 8 / 12 / 16 / 18\nCompact rows: 15\nSection gap: 14", 282, 306, 130, 10, "regular", colors.textSecondary, {
    lineHeight: 15
  });

  sectionTitle(parent, "Component styles", 282, 72, 128);
  planPill(parent, 282, 92, 82, false);
  quotaProgress(parent, "ComponentStyle/SampleProgress", 282, 128, 120, 0.62, colors.cyan);
  statusChip(parent, "SampleStatus", 282, 156, 118, "API Connected", colors.success);
  createText(parent, "ComponentStyle/Names", "WidgetBackground\nHeader\nAppIdentity\nPlanPill\nQuotaCard\nQuotaProgressBar\nTokenSummary\nTokenBreakdownRow\nStatusChip\nMiniTrendPlaceholder", 282, 190, 132, 10, "regular", colors.textMuted, {
    lineHeight: 14
  });
}

async function prepareFonts() {
  const available = await figma.listAvailableFontsAsync();
  const has = (family, style) => available.some((font) => font.fontName.family === family && font.fontName.style === style);
  const firstAvailable = available[0]?.fontName ?? { family: "Inter", style: "Regular" };

  function pick(styleCandidates) {
    const families = ["SF Pro Text", "SF Pro Display", "Inter", "Helvetica Neue"];
    for (const family of families) {
      for (const style of styleCandidates) {
        if (has(family, style)) return { family, style };
      }
    }
    return firstAvailable;
  }

  fonts = {
    regular: pick(["Regular", "Book"]),
    medium: pick(["Medium", "Regular"]),
    semibold: pick(["Semibold", "Semi Bold", "Demi Bold", "Medium", "Bold"]),
    bold: pick(["Bold", "Semi Bold", "Semibold", "Medium"])
  };

  const unique = new Map();
  Object.values(fonts).forEach((font) => unique.set(`${font.family}/${font.style}`, font));
  await Promise.all(Array.from(unique.values()).map((font) => figma.loadFontAsync(font)));
}

async function main() {
  await prepareFonts();

  const page = figma.createPage();
  page.name = PAGE_NAME;
  await figma.setCurrentPageAsync(page);
  page.backgrounds = paint(colors.canvas);

  const small = makeWidget(page, "QuotaScope / Widget / Small", 80, 80, 160, 160);
  createSmallWidget(small);

  const medium = makeWidget(page, "QuotaScope / Widget / Medium", 280, 80, 340, 160);
  createMediumWidget(medium);

  const large = makeWidget(page, "QuotaScope / Widget / Large", 80, 280, 340, 360);
  createLargeWidget(large);

  const designSystem = createFrame(page, "QuotaScope / Design System", 460, 280, 420, 440, {
    fill: colors.widgetBgAlt,
    radius: 22,
    stroke: colors.border,
    strokeOpacity: 0.08,
    effects: backgroundEffects()
  });
  createDesignSystem(designSystem);

  figma.viewport.scrollAndZoomIntoView([small, medium, large, designSystem]);
  console.log({ createdNodeIds, count: createdNodeIds.length });
  figma.closePlugin("QuotaScope WidgetKit widgets generated.");
}

main().catch((error) => {
  console.error(error);
  figma.closePlugin(`QuotaScope generation failed: ${error.message}`);
});
