import SwiftUI
import WidgetKit
#if WIDGET_PREVIEW_RENDER && os(macOS)
import AppKit
#endif

struct CodexUsageEntry: TimelineEntry {
    let date: Date
    let snapshot: CodexUsageSnapshot
}

struct CodexUsageProvider: TimelineProvider {
    private static let apiClient = CodexUsageAPIClient()

    func placeholder(in context: Context) -> CodexUsageEntry {
        Self.sampleEntry
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (CodexUsageEntry) -> Void) {
        let isPreview = context.isPreview
        Task {
            if isPreview {
                completion(Self.sampleEntry)
                return
            }

            let now = Date()
            let snapshot = await Self.apiClient.loadSnapshot(now: now)
            completion(CodexUsageEntry(date: now, snapshot: snapshot))
        }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<CodexUsageEntry>) -> Void) {
        Task {
            let now = Date()
            let entry = CodexUsageEntry(date: now, snapshot: await Self.apiClient.loadSnapshot(now: now))
            let nextUpdate = now.addingTimeInterval(CodexWidgetRefreshPolicy.timelineRefreshInterval)
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
        }
    }

    static let sampleDate = Date(timeIntervalSince1970: 1_779_770_520)

    static let sampleEntry = CodexUsageEntry(date: sampleDate, snapshot: sampleSnapshot)

    static let sampleSnapshot = CodexUsageSnapshot(
        latestEvent: CodexUsageEvent(
            timestamp: sampleDate,
            totalUsage: TokenUsage(inputTokens: 12_300_000, cachedInputTokens: 10_000_000, outputTokens: 45_000, totalTokens: 12_347_000),
            lastUsage: TokenUsage(inputTokens: 110_000, cachedInputTokens: 90_000, outputTokens: 10_000, totalTokens: 120_000),
            rateLimits: RateLimits(
                primary: RateWindow(usedPercent: 38, windowMinutes: 300, resetsAt: Date(timeIntervalSince1970: 1_779_783_600)),
                secondary: RateWindow(usedPercent: 19, windowMinutes: 10_080, resetsAt: Date(timeIntervalSince1970: 1_780_213_800)),
                planType: "prolite"
            )
        ),
        tokensLast5Hours: TokenUsage(totalTokens: 8_481_157),
        tokensLast7Days: TokenUsage(totalTokens: 176_629_938),
        tokensToday: TokenUsage(inputTokens: 129_800, cachedInputTokens: 91_600, outputTokens: 26_400, totalTokens: 128_400),
        tokensThisWeek: TokenUsage(inputTokens: 727_100, cachedInputTokens: 512_300, outputTokens: 85_600, totalTokens: 812_700),
        dailyUsageLast7Days: [
            CodexDailyUsage(date: Date(timeIntervalSince1970: 1_779_235_200), usage: TokenUsage(totalTokens: 90_000)),
            CodexDailyUsage(date: Date(timeIntervalSince1970: 1_779_321_600), usage: TokenUsage(totalTokens: 112_000)),
            CodexDailyUsage(date: Date(timeIntervalSince1970: 1_779_408_000), usage: TokenUsage(totalTokens: 98_000)),
            CodexDailyUsage(date: Date(timeIntervalSince1970: 1_779_494_400), usage: TokenUsage(totalTokens: 128_000)),
            CodexDailyUsage(date: Date(timeIntervalSince1970: 1_779_580_800), usage: TokenUsage(totalTokens: 76_000)),
            CodexDailyUsage(date: Date(timeIntervalSince1970: 1_779_667_200), usage: TokenUsage(totalTokens: 134_000)),
            CodexDailyUsage(date: Date(timeIntervalSince1970: 1_779_753_600), usage: TokenUsage(totalTokens: 128_400))
        ],
        eventCount: 3254
    )
}

struct CodexWatcherWidgetView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var widgetRenderingMode
    @Environment(\.showsWidgetContainerBackground) private var showsWidgetContainerBackground

    let entry: CodexUsageProvider.Entry
    var familyOverride: WidgetFamily?

    private var summary: CodexUsageSummary {
        CodexUsageSummary(snapshot: entry.snapshot, now: entry.date)
    }

    private var renderedFamily: WidgetFamily {
        familyOverride ?? family
    }

    private var resolvedPalette: WidgetPalette {
        WidgetPalette(
            colorScheme: colorScheme,
            renderingMode: widgetRenderingMode,
            showsWidgetContainerBackground: showsWidgetContainerBackground,
            forceDarkAppearance: renderedFamily == .systemLarge
        )
    }

    var body: some View {
        let palette = resolvedPalette

        Group {
            switch renderedFamily {
            case .systemSmall:
                SmallQuotaWidget(summary: summary)
            case .systemLarge:
                LargeQuotaWidget(summary: summary)
            default:
                MediumQuotaWidget(summary: summary)
            }
        }
        .environment(\.widgetPalette, palette)
        .containerBackground(for: .widget) {
            WidgetBackground(palette: palette, family: renderedFamily)
        }
    }
}

private struct SmallQuotaWidget: View {
    @Environment(\.widgetPalette) private var palette

    let summary: CodexUsageSummary

    var body: some View {
        VStack(spacing: 0) {
            WidgetHeader(summary: summary, size: .small)
                .frame(height: 24)
                .padding(.horizontal, 12)
                .padding(.top, 10)

            SmallQuotaStack(summary: summary)
                .frame(height: 72)
                .padding(.horizontal, 14)

            Spacer(minLength: 6)

            Rectangle()
                .fill(palette.divider)
                .frame(height: 1)
                .padding(.horizontal, 14)

            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text("Today")
                    .font(.system(size: 8.6, weight: .medium))
                    .foregroundStyle(palette.textSecondary)
                Spacer(minLength: 4)
                Text(summary.todayTokensText)
                    .font(.system(size: 15.5, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(height: 19)
            .padding(.horizontal, 14)
            .padding(.top, 3)

            Spacer(minLength: 0)

            CompactMCOSummary(summary: summary, alignment: .center, fontSize: 8.2)
                .frame(height: 12)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct MediumQuotaWidget: View {
    @Environment(\.widgetPalette) private var palette

    let summary: CodexUsageSummary

    var body: some View {
        VStack(spacing: 0) {
            WidgetHeader(summary: summary, size: .regular)
                .frame(height: 26)
                .padding(.horizontal, 18)
                .padding(.top, 12)

            HStack(alignment: .top, spacing: 0) {
                VStack(spacing: 6) {
                    QuotaCard(limit: summary.fiveHourQuotaLimit)
                    QuotaCard(limit: summary.sevenDayQuotaLimit)
                }
                .frame(width: 148)

                Rectangle()
                    .fill(palette.divider)
                    .frame(width: 1, height: 94)
                    .padding(.horizontal, 15)
                    .padding(.top, 2)

                TokenUsagePanel(summary: summary, style: .medium)
                    .frame(width: 132, height: 102)
            }
            .padding(.top, 12)
            .padding(.horizontal, 14)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct LargeQuotaWidget: View {
    let summary: CodexUsageSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetHeader(summary: summary, size: .regular)
                .frame(height: 26)
                .padding(.top, 14)

            Spacer()
                .frame(height: 14)

            SectionTitle("Quota Overview")

            Spacer()
                .frame(height: 5)

            HStack(spacing: 8) {
                QuotaCard(limit: summary.fiveHourQuotaLimit, style: .large)
                QuotaCard(limit: summary.sevenDayQuotaLimit, style: .large)
            }

            Spacer()
                .frame(height: 12)

            SectionTitle("Token Usage")

            Spacer()
                .frame(height: 7)

            SevenDayUsageChart(summary: summary)
                .frame(height: 174)
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct WidgetBackground: View {
    let palette: WidgetPalette
    let family: WidgetFamily

    private var cornerRadius: CGFloat {
        family == .systemSmall ? 24 : 28
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(palette.widgetBackground)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius - 1, style: .continuous)
                    .fill(palette.mintBrand.opacity(palette.isDark ? 0.018 : 0.045))
                    .padding(1)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(palette.widgetStroke, lineWidth: 1)
            }
    }
}

private struct WidgetHeader: View {
    @Environment(\.widgetPalette) private var palette

    enum Size {
        case small
        case regular
    }

    let summary: CodexUsageSummary
    let size: Size

    var body: some View {
        HStack(spacing: 0) {
            AppIdentity(summary: summary, size: size)
            Spacer(minLength: 10)
            if size == .regular {
                Text(summary.isEmpty ? "--" : summary.updatedAtText)
                    .font(.system(size: 9.5, weight: .regular))
                    .foregroundStyle(palette.textSecondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
    }
}

private struct AppIdentity: View {
    @Environment(\.widgetPalette) private var palette

    let summary: CodexUsageSummary
    let size: WidgetHeader.Size

    private var iconSize: CGFloat {
        size == .small ? 18 : 22
    }

    private var fontSize: CGFloat {
        size == .small ? 10.4 : 12
    }

    var body: some View {
        HStack(spacing: size == .small ? 6 : 8) {
            QuotaScopeLogo(size: iconSize)
            (Text(summary.title)
                .foregroundColor(palette.textPrimary)
             + Text(" · ")
                .foregroundColor(palette.textSecondary)
             + Text(summary.planBadgeText)
                .foregroundColor(palette.mintBrand))
                .font(.system(size: fontSize, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }
}

private struct QuotaScopeLogo: View {
    let size: CGFloat

    var body: some View {
        logoImage
            .resizable()
            .interpolation(.high)
            .antialiased(true)
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            .accessibilityHidden(true)
    }

    private var logoImage: Image {
        #if WIDGET_PREVIEW_RENDER && os(macOS)
        if let previewImage = Self.previewLogoImage {
            return Image(nsImage: previewImage)
        }
        #endif
        return Image("QuotaScopeLogo")
    }

    #if WIDGET_PREVIEW_RENDER && os(macOS)
    private static var previewLogoImage: NSImage? {
        let widgetSource = URL(fileURLWithPath: #filePath)
        let imageURL = widgetSource
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Assets.xcassets/QuotaScopeLogo.imageset/quotascope-logo@3x.png")
        return NSImage(contentsOf: imageURL)
    }
    #endif
}

private struct SmallQuotaStack: View {
    let summary: CodexUsageSummary

    var body: some View {
        VStack(spacing: 8) {
            SmallQuotaLine(limit: summary.fiveHourQuotaLimit)
            SmallQuotaLine(limit: summary.sevenDayQuotaLimit)
        }
    }
}

private struct QuotaLimitPresentation {
    let title: String
    let value: String
    let reset: String
    let percent: Double?
    let tint: QuotaTint
}

private extension CodexUsageSummary {
    var fiveHourQuotaLimit: QuotaLimitPresentation {
        QuotaLimitPresentation(
            title: fiveHourLimitLabelText,
            value: fiveHourLimitText,
            reset: fiveHourResetText,
            percent: fiveHourLimitPercent,
            tint: .fiveHour
        )
    }

    var sevenDayQuotaLimit: QuotaLimitPresentation {
        QuotaLimitPresentation(
            title: sevenDayLimitLabelText,
            value: sevenDayLimitText,
            reset: sevenDayResetText,
            percent: sevenDayLimitPercent,
            tint: .sevenDay
        )
    }
}

private struct SmallQuotaLine: View {
    @Environment(\.widgetPalette) private var palette

    let limit: QuotaLimitPresentation

    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .top, spacing: 6) {
                Text(limit.title)
                    .font(.system(size: 8.8, weight: .medium))
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 0) {
                    Text(limit.value)
                        .font(.system(size: 10.5, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(palette.textPrimary)
                    Text(limit.reset)
                        .font(.system(size: 7.6, weight: .regular))
                        .monospacedDigit()
                        .foregroundStyle(palette.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }

            QuotaProgressBar(percent: limit.percent, tint: limit.tint)
                .frame(height: 4)
        }
        .frame(height: 32)
    }
}

private struct QuotaCard: View {
    @Environment(\.widgetPalette) private var palette

    enum Style {
        case medium
        case large

        var size: CGSize {
            switch self {
            case .medium:
                return CGSize(width: 148, height: 45)
            case .large:
                return CGSize(width: 148, height: 45)
            }
        }

        var titleFontSize: CGFloat {
            switch self {
            case .medium:
                return 9.4
            case .large:
                return 9.4
            }
        }

        var valueFontSize: CGFloat {
            switch self {
            case .medium:
                return 11
            case .large:
                return 11
            }
        }

        var resetFontSize: CGFloat {
            switch self {
            case .medium:
                return 8.8
            case .large:
                return 8.8
            }
        }

        var progressHeight: CGFloat {
            switch self {
            case .medium:
                return 4
            case .large:
                return 4
            }
        }

        var topPadding: CGFloat {
            switch self {
            case .medium:
                return 7
            case .large:
                return 7
            }
        }

        var bottomPadding: CGFloat {
            switch self {
            case .medium:
                return 6
            case .large:
                return 6
            }
        }
    }

    let limit: QuotaLimitPresentation
    var style: Style = .medium

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(limit.title)
                    .font(.system(size: style.titleFontSize, weight: .medium))
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Spacer(minLength: 4)

                Text(limit.value)
                    .font(.system(size: style.valueFontSize, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(palette.textPrimary)
            }

            Text(limit.reset)
                .font(.system(size: style.resetFontSize, weight: .regular))
                .monospacedDigit()
                .foregroundStyle(palette.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .allowsTightening(true)
                .frame(maxWidth: .infinity, alignment: .trailing)

            Spacer(minLength: 3)

            QuotaProgressBar(percent: limit.percent, tint: limit.tint)
                .frame(height: style.progressHeight)
        }
        .padding(.horizontal, 10)
        .padding(.top, style.topPadding)
        .padding(.bottom, style.bottomPadding)
        .frame(width: style.size.width, height: style.size.height)
        .background(palette.cardSurface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(palette.cardStroke, lineWidth: 1)
        }
    }
}

private struct QuotaProgressBar: View {
    @Environment(\.widgetPalette) private var palette

    let percent: Double?
    let tint: QuotaTint

    private var normalized: Double {
        min(max((percent ?? 0) / 100, 0), 1)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(palette.progressTrack)
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(tint.color(in: palette))
                    .frame(width: geometry.size.width * normalized)
                    .widgetAccentable()
            }
        }
    }
}

private struct TokenUsagePanel: View {
    @Environment(\.widgetPalette) private var palette

    enum Style {
        case medium
        case largeHeader
    }

    let summary: CodexUsageSummary
    let style: Style

    var body: some View {
        switch style {
        case .medium:
            mediumBody
        case .largeHeader:
            largeHeaderBody
        }
    }

    private var mediumBody: some View {
        VStack(spacing: 0) {
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text("Today")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(palette.textSecondary)
                Spacer(minLength: 4)
                Text(summary.todayTokensText)
                    .font(.system(size: 18, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(height: 21)

            VStack(spacing: 1) {
                TokenBreakdownRow(kind: .miss, value: summary.todayInputMissText)
                TokenBreakdownRow(kind: .cache, value: summary.todayInputCacheText)
                TokenBreakdownRow(kind: .output, value: summary.todayOutputText)
            }
            .padding(.top, 8)

            Rectangle()
                .fill(palette.divider)
                .frame(height: 1)
                .padding(.top, 4)

            WeekSummarySubtle(text: summary.weekSummaryText)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 8)
        }
    }

    private var largeHeaderBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Today")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(palette.textSecondary)
                .frame(height: 12)
            Text(summary.todayTokensText)
                .font(.system(size: 22, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(height: 25, alignment: .leading)
        }
    }
}

private struct TokenBreakdownRow: View {
    @Environment(\.widgetPalette) private var palette

    let kind: TokenBreakdownKind
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(kind.color(in: palette))
                .frame(width: 6, height: 6)
                .widgetAccentable()

            Text(kind.title)
                .font(.system(size: 9.7, weight: .regular))
                .foregroundStyle(palette.textSecondary)
                .lineLimit(1)

            Spacer(minLength: 4)

            Text(value)
                .font(.system(size: 9.7, weight: .regular))
                .monospacedDigit()
                .foregroundStyle(palette.textSecondary)
                .lineLimit(1)
        }
        .frame(height: 14)
    }
}

private struct CompactMCOSummary: View {
    @Environment(\.widgetPalette) private var palette

    let summary: CodexUsageSummary
    let alignment: Alignment
    let fontSize: CGFloat

    var body: some View {
        mcoText
            .font(.system(size: fontSize, weight: .regular))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity, alignment: alignment)
    }

    private var mcoText: Text {
        Text("M ")
            .foregroundColor(palette.mintBrand)
            .fontWeight(.semibold)
        + Text(summary.todayInputMissText)
            .foregroundColor(palette.textSecondary)
        + Text("   C ")
            .foregroundColor(palette.inputCache)
            .fontWeight(.semibold)
        + Text(summary.todayInputCacheText)
            .foregroundColor(palette.textSecondary)
        + Text("   O ")
            .foregroundColor(palette.outputSilver)
            .fontWeight(.semibold)
        + Text(summary.todayOutputText)
            .foregroundColor(palette.textSecondary)
    }
}

private struct WeekSummarySubtle: View {
    @Environment(\.widgetPalette) private var palette

    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 9.6, weight: .regular))
            .monospacedDigit()
            .foregroundStyle(palette.textTertiary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

private struct SectionTitle: View {
    @Environment(\.widgetPalette) private var palette

    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 9.5, weight: .semibold))
            .foregroundStyle(palette.textSecondary)
            .frame(height: 12, alignment: .leading)
    }
}

private struct SevenDayUsageChart: View {
    @Environment(\.widgetPalette) private var palette

    let summary: CodexUsageSummary

    private var bars: [CodexWidgetWeeklyBar] {
        summary.weeklyBars
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                TokenUsagePanel(summary: summary, style: .largeHeader)
                    .frame(width: 126, alignment: .leading)

                Spacer(minLength: 16)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Week")
                        .font(.system(size: 8.2, weight: .regular))
                        .foregroundStyle(palette.textTertiary)
                    Text(summary.thisWeekTokensText)
                        .font(.system(size: 10.8, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(palette.textSecondary.opacity(0.72))
                }
                .frame(width: 58, alignment: .trailing)
            }
            .padding(.top, 10)
            .padding(.horizontal, 14)

            CompactMCOSummary(summary: summary, alignment: .leading, fontSize: 8.4)
                .frame(width: 160, height: 11)
                .padding(.top, 2)
                .padding(.horizontal, 14)

            Spacer(minLength: 2)

            ChartBars(bars: bars)
                .padding(.horizontal, 14)
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.cardSurface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(palette.chartStroke, lineWidth: 1)
        }
    }
}

private struct ChartBars: View {
    @Environment(\.widgetPalette) private var palette

    let bars: [CodexWidgetWeeklyBar]

    private let barWidth: CGFloat = 18
    private let labelWidth: CGFloat = 34
    private let maxBarHeight: CGFloat = 64

    var body: some View {
        VStack(spacing: 3) {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(palette.chartGuide)
                        .frame(height: 1)
                    Spacer()
                    Rectangle()
                        .fill(palette.chartBaseline)
                        .frame(height: 1)
                }
                .frame(height: maxBarHeight)
                .padding(.top, 10)

                HStack(alignment: .bottom, spacing: 5) {
                    ForEach(Array(bars.enumerated()), id: \.offset) { _, bar in
                        ChartBar(bar: bar, maxBarHeight: maxBarHeight, columnWidth: labelWidth, barWidth: barWidth)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: 74)

            HStack(spacing: 5) {
                ForEach(Array(bars.enumerated()), id: \.offset) { _, bar in
                    Text(bar.label)
                        .font(.system(size: bar.isToday ? 8.7 : 8.3, weight: bar.isToday ? .semibold : .regular))
                        .foregroundStyle(bar.isToday ? palette.mintBrand : palette.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(width: labelWidth)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct ChartBar: View {
    @Environment(\.widgetPalette) private var palette

    let bar: CodexWidgetWeeklyBar
    let maxBarHeight: CGFloat
    let columnWidth: CGFloat
    let barWidth: CGFloat

    private var barHeight: CGFloat {
        guard bar.normalizedHeight > 0 else {
            return 0
        }
        return max(4, CGFloat(bar.normalizedHeight) * maxBarHeight)
    }

    var body: some View {
        VStack(spacing: 4) {
            if bar.isValueTextVisible {
                Text(bar.valueText)
                    .font(.system(size: bar.isToday ? 8.2 : 7.4, weight: bar.isToday ? .semibold : .medium))
                    .monospacedDigit()
                    .foregroundStyle(bar.isToday ? palette.mintBrand : palette.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    .frame(height: 10)
                    .frame(width: columnWidth)
                    .widgetAccentable(bar.isToday)
            } else {
                Spacer()
                    .frame(height: 10)
            }

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(bar.isToday ? palette.mintBrand : palette.lavender7d.opacity(palette.isDark ? 0.55 : 0.50))
                .frame(width: barWidth, height: barHeight)
                .widgetAccentable(bar.isToday)
        }
        .frame(width: columnWidth, height: maxBarHeight + 10, alignment: .bottom)
    }
}

private enum QuotaTint {
    case fiveHour
    case sevenDay

    func color(in palette: WidgetPalette) -> Color {
        switch self {
        case .fiveHour:
            return palette.mintBrand
        case .sevenDay:
            return palette.lavender7d
        }
    }
}

private enum TokenBreakdownKind {
    case miss
    case cache
    case output

    var title: String {
        switch self {
        case .miss:
            return "Input miss"
        case .cache:
            return "Input cache"
        case .output:
            return "Output"
        }
    }

    func color(in palette: WidgetPalette) -> Color {
        switch self {
        case .miss:
            return palette.mintBrand
        case .cache:
            return palette.inputCache
        case .output:
            return palette.outputSilver
        }
    }
}

private struct WidgetPalette {
    let colorScheme: ColorScheme
    private let usesDesktopTintedRendering: Bool

    init(
        colorScheme: ColorScheme,
        renderingMode: WidgetRenderingMode,
        showsWidgetContainerBackground: Bool,
        forceDarkAppearance: Bool = false
    ) {
        let resolvedColorScheme = forceDarkAppearance ? ColorScheme.dark : colorScheme
        self.colorScheme = resolvedColorScheme
        usesDesktopTintedRendering = !showsWidgetContainerBackground
            || renderingMode == .accented
            || renderingMode == .vibrant
    }

    var isDark: Bool {
        colorScheme == .dark
    }

    var widgetBackground: Color {
        if usesDesktopTintedRendering {
            return isDark ? Self.hex(0x171B21, opacity: 0.82) : Self.hex(0xF7FAF8, opacity: 0.72)
        }
        return isDark ? Self.hex(0x171B21) : Self.hex(0xFBFCFA)
    }

    var widgetStroke: Color {
        if usesDesktopTintedRendering {
            return isDark ? Self.hex(0xFFFFFF, opacity: 0.10) : Self.hex(0x0F1715, opacity: 0.10)
        }
        return isDark ? Self.hex(0xFFFFFF, opacity: 0.075) : Self.hex(0x0F1715, opacity: 0.09)
    }

    var cardSurface: Color {
        if usesDesktopTintedRendering {
            return isDark ? Self.hex(0x1B2327, opacity: 0.88) : Self.hex(0xFFFFFF, opacity: 0.62)
        }
        return isDark ? Self.hex(0x1B2327) : .white
    }

    var cardStroke: Color {
        if usesDesktopTintedRendering {
            return isDark ? Self.hex(0xFFFFFF, opacity: 0.08) : Self.hex(0x0F1715, opacity: 0.10)
        }
        return isDark ? Self.hex(0xFFFFFF, opacity: 0.06) : Self.hex(0x0F1715, opacity: 0.08)
    }

    var chartStroke: Color {
        if usesDesktopTintedRendering {
            return isDark ? Self.hex(0xFFFFFF, opacity: 0.10) : Self.hex(0x0F1715, opacity: 0.10)
        }
        return isDark ? Self.hex(0x303B3F) : Self.hex(0xE3E8E4)
    }

    var textPrimary: Color {
        if usesDesktopTintedRendering {
            return isDark ? Self.hex(0xF3F8F5, opacity: 0.96) : Self.hex(0x111917, opacity: 0.94)
        }
        return isDark ? Self.hex(0xF3F8F5) : Self.hex(0x17211E)
    }

    var textSecondary: Color {
        if usesDesktopTintedRendering {
            return isDark ? Self.hex(0x93A09A, opacity: 0.92) : Self.hex(0x4F5C56, opacity: 0.92)
        }
        return isDark ? Self.hex(0x81908A) : Self.hex(0x72807B)
    }

    var textTertiary: Color {
        if usesDesktopTintedRendering {
            return isDark ? Self.hex(0x70807A, opacity: 0.88) : Self.hex(0x6F7B75, opacity: 0.86)
        }
        return isDark ? Self.hex(0x586864) : Self.hex(0x9FAAA4)
    }

    var mintBrand: Color {
        if usesDesktopTintedRendering {
            return isDark ? Self.hex(0x63D894) : Self.hex(0x20B66F)
        }
        return isDark ? Self.hex(0x63D894) : Self.hex(0x2FB979)
    }

    var lavender7d: Color {
        if usesDesktopTintedRendering {
            return isDark ? Self.hex(0xB7A8F6) : Self.hex(0x7B62CF)
        }
        return isDark ? Self.hex(0xB7A8F6) : Self.hex(0x8B74D7)
    }

    var inputCache: Color {
        if usesDesktopTintedRendering {
            return isDark ? Self.hex(0xA6E9BB) : Self.hex(0x59B87C)
        }
        return isDark ? Self.hex(0xA6E9BB) : Self.hex(0x62B580)
    }

    var outputSilver: Color {
        if usesDesktopTintedRendering {
            return isDark ? Self.hex(0xD3DEDB) : Self.hex(0x7C8A84)
        }
        return isDark ? Self.hex(0xD3DEDB) : Self.hex(0x859691)
    }

    var divider: Color {
        if usesDesktopTintedRendering {
            return isDark ? Self.hex(0xFFFFFF, opacity: 0.09) : Self.hex(0x0F1715, opacity: 0.12)
        }
        return isDark ? Self.hex(0xFFFFFF, opacity: 0.08) : Self.hex(0x0F1715, opacity: 0.10)
    }

    var progressTrack: Color {
        if usesDesktopTintedRendering {
            return isDark ? Self.hex(0x303B3F, opacity: 0.86) : Self.hex(0x0F1715, opacity: 0.12)
        }
        return isDark ? Self.hex(0x303B3F) : Self.hex(0xDCE5DF)
    }

    var chartGuide: Color {
        if usesDesktopTintedRendering {
            return isDark ? Self.hex(0xFFFFFF, opacity: 0.08) : Self.hex(0x0F1715, opacity: 0.11)
        }
        return isDark ? Self.hex(0x303B3F, opacity: 0.75) : Self.hex(0xE3E8E4, opacity: 0.90)
    }

    var chartBaseline: Color {
        if usesDesktopTintedRendering {
            return isDark ? Self.hex(0xFFFFFF, opacity: 0.09) : Self.hex(0x0F1715, opacity: 0.13)
        }
        return isDark ? Self.hex(0x303B3F, opacity: 0.90) : Self.hex(0xE3E8E4)
    }

    static func hex(_ value: Int, opacity: Double = 1) -> Color {
        Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255,
            opacity: opacity
        )
    }
}

private struct WidgetPaletteKey: EnvironmentKey {
    static let defaultValue = WidgetPalette(
        colorScheme: .light,
        renderingMode: .fullColor,
        showsWidgetContainerBackground: true
    )
}

private extension EnvironmentValues {
    var widgetPalette: WidgetPalette {
        get { self[WidgetPaletteKey.self] }
        set { self[WidgetPaletteKey.self] = newValue }
    }
}

#if !WIDGET_PREVIEW_RENDER
@main
struct CodexWatcherWidget: Widget {
    let kind = "QuotaScopeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CodexUsageProvider()) { entry in
            CodexWatcherWidgetView(entry: entry)
        }
        .configurationDisplayName("QuotaScope")
        .description("Track Codex quota from the usage API and local usage.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
        .containerBackgroundRemovable(false)
    }
}

struct CodexWatcherWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CodexWatcherWidgetView(entry: CodexUsageProvider.sampleEntry)
                .previewDisplayName("Small Dark")
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .preferredColorScheme(.dark)

            CodexWatcherWidgetView(entry: CodexUsageProvider.sampleEntry)
                .previewDisplayName("Small Light")
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .preferredColorScheme(.light)

            CodexWatcherWidgetView(entry: CodexUsageProvider.sampleEntry)
                .previewDisplayName("Medium Dark")
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .preferredColorScheme(.dark)

            CodexWatcherWidgetView(entry: CodexUsageProvider.sampleEntry)
                .previewDisplayName("Medium Light")
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .preferredColorScheme(.light)

            CodexWatcherWidgetView(entry: CodexUsageProvider.sampleEntry)
                .previewDisplayName("Large Dark")
                .previewContext(WidgetPreviewContext(family: .systemLarge))
                .preferredColorScheme(.dark)

            CodexWatcherWidgetView(entry: CodexUsageProvider.sampleEntry)
                .previewDisplayName("Large Light")
                .previewContext(WidgetPreviewContext(family: .systemLarge))
                .preferredColorScheme(.light)
        }
    }
}
#endif
