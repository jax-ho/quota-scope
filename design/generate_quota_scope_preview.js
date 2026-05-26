const fs = require("fs");
const path = require("path");

const outPath = path.join(__dirname, "quota_scope_widgetkit_preview.svg");

const C = {
  canvas: "#0D1116",
  widgetBg: "#171B21",
  widgetAlt: "#1B2027",
  surface: "#222833",
  surfaceAlt: "#262D38",
  track: "#303845",
  border: "rgba(255,255,255,.08)",
  hairline: "rgba(255,255,255,.08)",
  text: "#F3F6FA",
  secondary: "#B8C1CF",
  muted: "#7E8A9B",
  brand: "#6EA8FF",
  cyan: "#6DD6DD",
  indigo: "#9AA7FF",
  miss: "#78BFFB",
  cache: "#84D9AA",
  output: "#B5A2FF",
  success: "#74D99F"
};

const svg = [];

function esc(value) {
  return String(value).replace(/[&<>"']/g, (char) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    "\"": "&quot;",
    "'": "&apos;"
  }[char]));
}

function el(tag, attrs = {}, children = "") {
  const attr = Object.entries(attrs)
    .filter(([, value]) => value !== undefined && value !== null)
    .map(([key, value]) => `${key}="${esc(value)}"`)
    .join(" ");
  svg.push(`<${tag}${attr ? ` ${attr}` : ""}>${children}</${tag}>`);
}

function raw(value) {
  svg.push(value);
}

function rect(x, y, w, h, fill, r = 0, extra = {}) {
  el("rect", { x, y, width: w, height: h, rx: r, ry: r, fill, ...extra });
}

function text(value, x, y, size, fill = C.text, weight = 400, extra = {}) {
  el("text", {
    x,
    y,
    fill,
    "font-size": size,
    "font-weight": weight,
    "font-family": "-apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Inter', sans-serif",
    "font-variant-numeric": "tabular-nums",
    "letter-spacing": 0,
    ...extra
  }, esc(value));
}

function line(x1, y1, x2, y2, stroke, width = 1, extra = {}) {
  el("line", { x1, y1, x2, y2, stroke, "stroke-width": width, "stroke-linecap": "round", ...extra });
}

function circle(cx, cy, r, fill, extra = {}) {
  el("circle", { cx, cy, r, fill, ...extra });
}

function widget(x, y, w, h, name) {
  raw(`<g id="${esc(name)}" filter="url(#widgetShadow)">`);
  rect(x, y, w, h, C.widgetBg, w <= 170 ? 24 : 28, {
    stroke: C.border,
    "stroke-width": 1
  });
  rect(x + 1, y + 1, w - 2, h - 2, "url(#materialWash)", w <= 170 ? 23 : 27, {
    opacity: 0.48
  });
  raw("</g>");
}

function icon(x, y, s) {
  raw(`<g id="AppIdentity_TemporaryQuotaScopeIcon" transform="translate(${x} ${y})">`);
  rect(0, 0, s, s, C.surfaceAlt, s * 0.24, { stroke: "rgba(255,255,255,.12)" });
  rect(0, 0, s, s, "rgba(110,168,255,.16)", s * 0.24);
  el("circle", {
    cx: s * 0.435,
    cy: s * 0.415,
    r: s * 0.215,
    fill: "none",
    stroke: C.cyan,
    "stroke-width": Math.max(1.4, s * 0.075)
  });
  line(s * 0.62, s * 0.63, s * 0.82, s * 0.82, C.indigo, Math.max(1.4, s * 0.075));
  rect(s * 0.2, s * 0.72, s * 0.5, s * 0.06, C.brand, s * 0.03, { opacity: 0.8 });
  raw("</g>");
}

function pill(x, y, w, label) {
  rect(x, y, w, 18, "rgba(110,168,255,.12)", 9, {
    stroke: "rgba(110,168,255,.22)"
  });
  text(label, x + w / 2, y + 12.5, 10, C.brand, 500, { "text-anchor": "middle" });
}

function progress(x, y, w, ratio, fill, id) {
  raw(`<g id="${esc(id)}_QuotaProgressBar">`);
  rect(x, y, w, 5, C.track, 3);
  rect(x, y, Math.max(5, w * ratio), 5, fill, 3);
  raw("</g>");
}

function divider(x, y, w, h) {
  rect(x, y, w, h, C.hairline, 1);
}

function quotaCard(x, y, w, h, label, value, reset, ratio, fill, id) {
  raw(`<g id="QuotaCard_${esc(id)}">`);
  rect(x, y, w, h, C.surface, 10, { stroke: "rgba(255,255,255,.06)" });
  const compact = h <= 50;
  text(label, x + 10, y + 18, 10, C.muted, 500);
  text(value, x + 10, y + (compact ? 31 : 34), compact ? 13 : 14, C.text, 600);
  text(reset, x + w - 10, y + 18, 10, C.muted, 400, { "text-anchor": "end" });
  progress(x + 10, y + (compact ? h - 8 : h - 12), w - 20, ratio, fill, id);
  raw("</g>");
}

function tokenRow(x, y, label, value, fill, width, id) {
  raw(`<g id="TokenBreakdownRow_${esc(id)}">`);
  circle(x + 3, y + 6, 3, fill);
  text(label, x + 11, y + 10, 10, C.muted, 400);
  text(value, x + width, y + 10, 10, C.secondary, 500, { "text-anchor": "end" });
  raw("</g>");
}

function statusChip(x, y, w, label, id) {
  raw(`<g id="StatusChip_${esc(id)}">`);
  rect(x, y, w, 22, C.surface, 11, { stroke: "rgba(255,255,255,.07)" });
  circle(x + 12, y + 11, 3, C.success);
  text(label, x + 20, y + 14, 10, C.secondary, 500);
  raw("</g>");
}

function section(label, x, y) {
  text(label, x, y, 10, C.muted, 700);
}

function small() {
  const x = 80;
  const y = 86;
  widget(x, y, 160, 160, "QuotaScope / Widget / Small");
  icon(x + 14, y + 12, 22);
  text("QuotaScope", x + 42, y + 25, 11, C.text, 700);
  text("plan prolite", x + 42, y + 39, 10, C.muted);

  text("5h", x + 14, y + 63, 11, C.secondary, 500);
  text("62%", x + 146, y + 63, 11, C.text, 700, { "text-anchor": "end" });
  progress(x + 14, y + 68, 132, 0.62, C.cyan, "Small_5h");

  text("7d", x + 14, y + 92, 11, C.secondary, 500);
  text("81%", x + 146, y + 92, 11, C.text, 700, { "text-anchor": "end" });
  progress(x + 14, y + 97, 132, 0.81, C.indigo, "Small_7d");

  divider(x + 14, y + 111, 132, 1);
  text("Today", x + 14, y + 130, 10, C.muted, 500);
  text("128.4K", x + 146, y + 132, 18, C.text, 700, { "text-anchor": "end" });
  text("M38.2K  C91.6K  O26.4K", x + 80, y + 151, 8.5, C.muted, 400, { "text-anchor": "middle" });
}

function medium() {
  const x = 280;
  const y = 86;
  widget(x, y, 340, 160, "QuotaScope / Widget / Medium");
  icon(x + 16, y + 14, 22);
  text("QuotaScope", x + 46, y + 27, 12, C.text, 700);
  text("quota and tokens", x + 46, y + 40, 9.5, C.muted);
  pill(x + 248, y + 15, 76, "plan prolite");

  quotaCard(x + 14, y + 50, 148, 45, "5h limit", "62% remaining", "until 16:20", 0.62, C.cyan, "Medium_5h");
  quotaCard(x + 14, y + 101, 148, 45, "7d limit", "81% remaining", "05/31 15:50", 0.81, C.indigo, "Medium_7d");
  divider(x + 176, y + 52, 1, 94);

  text("Today", x + 192, y + 64, 10, C.muted, 500);
  text("128.4K", x + 324, y + 66, 18, C.text, 700, { "text-anchor": "end" });
  text("Week", x + 192, y + 87, 10, C.muted, 500);
  text("812.7K", x + 324, y + 89, 18, C.secondary, 700, { "text-anchor": "end" });
  divider(x + 192, y + 98, 132, 1);
  tokenRow(x + 192, y + 108, "Input miss", "38.2K", C.miss, 132, "Medium_InputMiss");
  tokenRow(x + 192, y + 123, "Input cache", "91.6K", C.cache, 132, "Medium_InputCache");
  tokenRow(x + 192, y + 138, "Output", "26.4K", C.output, 132, "Medium_Output");
}

function summaryCard(x, y, w, title, value, id) {
  raw(`<g id="TokenSummary_${esc(id)}">`);
  rect(x, y, w, 48, C.surface, 11, { stroke: "rgba(255,255,255,.06)" });
  text(title, x + 10, y + 20, 10, C.muted, 500);
  text(value, x + 10, y + 39, 18, C.text, 700);
  raw("</g>");
}

function breakdownCard(x, y, w, title, rows, id) {
  raw(`<g id="TokenBreakdownCard_${esc(id)}">`);
  rect(x, y, w, 64, C.surface, 11, { stroke: "rgba(255,255,255,.06)" });
  text(title, x + 10, y + 20, 10, C.secondary, 700);
  rows.forEach((row, i) => tokenRow(x + 10, y + 24 + i * 13, row[0], row[1], row[2], w - 20, `${id}_${i}`));
  raw("</g>");
}

function burnRate(x, y, w) {
  raw(`<g id="MiniTrendPlaceholder">`);
  rect(x, y, w, 22, C.surface, 11, { stroke: "rgba(255,255,255,.07)" });
  text("Burn rate", x + 9, y + 14, 9.5, C.muted, 500);
  const pts = [[x + 58, y + 14], [x + 66, y + 11], [x + 74, y + 13], [x + 82, y + 8], [x + 90, y + 10], [x + 98, y + 7]];
  for (let i = 0; i < pts.length - 1; i += 1) {
    line(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], C.cyan, 1.2, { opacity: 0.55 });
  }
  raw("</g>");
}

function large() {
  const x = 80;
  const y = 286;
  widget(x, y, 340, 360, "QuotaScope / Widget / Large");
  icon(x + 18, y + 16, 24);
  text("QuotaScope", x + 50, y + 30, 13, C.text, 700);
  text("Last updated 12:42", x + 322, y + 30, 10, C.muted, 400, { "text-anchor": "end" });
  pill(x + 50, y + 33, 82, "plan prolite");

  section("Quota Overview", x + 18, y + 73);
  quotaCard(x + 18, y + 78, 146, 58, "5h limit", "62% remaining", "until 16:20", 0.62, C.cyan, "Large_5h");
  quotaCard(x + 176, y + 78, 146, 58, "7d limit", "81% remaining", "05/31 15:50", 0.81, C.indigo, "Large_7d");

  section("Token Usage", x + 18, y + 163);
  summaryCard(x + 18, y + 168, 146, "Today", "128.4K tokens", "Large_Today");
  summaryCard(x + 176, y + 168, 146, "Week", "812.7K tokens", "Large_Week");

  breakdownCard(x + 18, y + 226, 146, "Today breakdown", [
    ["Input miss", "38.2K", C.miss],
    ["Input cache", "91.6K", C.cache],
    ["Output", "26.4K", C.output]
  ], "Today");
  breakdownCard(x + 176, y + 226, 146, "Week breakdown", [
    ["Input miss", "214.8K", C.miss],
    ["Input cache", "512.3K", C.cache],
    ["Output", "85.6K", C.output]
  ], "Week");

  section("System Status / Future", x + 18, y + 316);
  statusChip(x + 18, y + 322, 92, "API Connected", "APIConnected");
  statusChip(x + 118, y + 322, 104, "Cache Healthy", "CacheHealthy");
  burnRate(x + 232, y + 322, 90);
}

function swatch(x, y, fill, label, id) {
  raw(`<g id="ColorToken_${esc(id)}">`);
  rect(x, y, 18, 18, fill, 5, { stroke: "rgba(255,255,255,.10)" });
  text(label, x + 26, y + 13, 10, C.secondary);
  raw("</g>");
}

function designSystem() {
  const x = 460;
  const y = 286;
  raw(`<g id="QuotaScope / Design System" filter="url(#widgetShadow)">`);
  rect(x, y, 420, 360, C.widgetAlt, 22, { stroke: C.border });
  text("QuotaScope Widget Design System", x + 22, y + 38, 16, C.text, 700);
  text("SwiftUI-friendly tokens for WidgetKit desktop widgets", x + 22, y + 56, 10, C.muted);

  section("Color tokens", x + 22, y + 86);
  swatch(x + 22, y + 98, C.widgetBg, "WidgetBackground", "WidgetBackground");
  swatch(x + 22, y + 124, C.surface, "Surface", "Surface");
  swatch(x + 22, y + 150, C.brand, "Brand", "Brand");
  swatch(x + 22, y + 176, C.cyan, "Quota5h", "Quota5h");
  swatch(x + 22, y + 202, C.indigo, "Quota7d", "Quota7d");
  swatch(x + 186, y + 98, C.miss, "Input miss", "InputMiss");
  swatch(x + 186, y + 124, C.cache, "Input cache", "InputCache");
  swatch(x + 186, y + 150, C.output, "Output", "Output");
  swatch(x + 186, y + 176, C.success, "Success", "Success");
  swatch(x + 186, y + 202, "rgba(255,255,255,.08)", "Divider 8%", "Divider");

  section("Type scale", x + 22, y + 246);
  text("Title 16 Semibold", x + 22, y + 270, 16, C.text, 700);
  text("Metric 20 Semibold", x + 22, y + 300, 20, C.text, 700);
  text("Caption 10 Regular", x + 22, y + 328, 10, C.muted);
  text("Use tabular numbers for quota and token values.", x + 22, y + 348, 10, C.muted);

  section("Component styles", x + 282, y + 246);
  pill(x + 282, y + 256, 82, "plan prolite");
  progress(x + 282, y + 292, 120, 0.62, C.cyan, "System_Sample");
  statusChip(x + 282, y + 318, 118, "API Connected", "SampleStatus");
  raw("</g>");
}

raw(`<svg xmlns="http://www.w3.org/2000/svg" width="960" height="720" viewBox="0 0 960 720" role="img" aria-label="QuotaScope WidgetKit widget designs">`);
raw(`<defs>
  <linearGradient id="pageBg" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#10151C"/>
    <stop offset="1" stop-color="#0B0E13"/>
  </linearGradient>
  <linearGradient id="materialWash" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#FFFFFF" stop-opacity=".055"/>
    <stop offset=".58" stop-color="#6EA8FF" stop-opacity=".025"/>
    <stop offset="1" stop-color="#000000" stop-opacity=".08"/>
  </linearGradient>
  <filter id="widgetShadow" x="-20%" y="-20%" width="140%" height="150%">
    <feDropShadow dx="0" dy="18" stdDeviation="15" flood-color="#000000" flood-opacity=".24"/>
  </filter>
</defs>`);
rect(0, 0, 960, 720, "url(#pageBg)");
text("QuotaScope WidgetKit Desktop Widgets", 80, 48, 22, C.text, 700);
text("small / medium / large information architecture, plus implementation tokens", 80, 70, 12, C.muted);
small();
medium();
large();
designSystem();
raw("</svg>");

fs.writeFileSync(outPath, svg.join("\n"));
console.log(outPath);
