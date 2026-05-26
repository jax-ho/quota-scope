import SwiftUI
import WidgetKit

struct CodexUsageEntry: TimelineEntry {
    let date: Date
    let snapshot: CodexUsageSnapshot
}

struct CodexUsageProvider: TimelineProvider {
    private static let apiClient = CodexUsageAPIClient()

    func placeholder(in context: Context) -> CodexUsageEntry {
        CodexUsageEntry(date: Date(), snapshot: Self.sampleSnapshot)
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (CodexUsageEntry) -> Void) {
        Task {
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

    private static let sampleSnapshot = CodexUsageSnapshot(
        latestEvent: CodexUsageEvent(
            timestamp: Date(),
            totalUsage: TokenUsage(inputTokens: 12_300_000, cachedInputTokens: 10_000_000, outputTokens: 45_000, totalTokens: 12_347_000),
            lastUsage: TokenUsage(inputTokens: 110_000, cachedInputTokens: 90_000, outputTokens: 10_000, totalTokens: 120_000),
            rateLimits: RateLimits(
                primary: RateWindow(usedPercent: 7, windowMinutes: 300),
                secondary: RateWindow(usedPercent: 20, windowMinutes: 10_080),
                planType: "plus"
            )
        ),
        tokensLast5Hours: TokenUsage(totalTokens: 8_481_157),
        tokensLast7Days: TokenUsage(totalTokens: 176_629_938),
        tokensToday: TokenUsage(inputTokens: 48_900_000, cachedInputTokens: 39_800_000, outputTokens: 2_700_000, totalTokens: 51_600_000),
        tokensThisWeek: TokenUsage(inputTokens: 205_700_000, cachedInputTokens: 164_300_000, outputTokens: 9_900_000, totalTokens: 215_600_000),
        eventCount: 3254
    )
}

struct CodexWatcherWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CodexUsageProvider.Entry

    private var summary: CodexUsageSummary {
        CodexUsageSummary(snapshot: entry.snapshot, now: entry.date)
    }

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                smallView
            default:
                mediumView
            }
        }
        .containerBackground(.background, for: .widget)
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: CGFloat(CodexWidgetLayoutMetrics.smallSectionSpacing)) {
            header
            limitRow(summary.fiveHourLimitLabelText, summary.fiveHourLimitText, summary.fiveHourLimitPercent)
            limitRow(summary.sevenDayLimitLabelText, summary.sevenDayLimitText, summary.sevenDayLimitPercent)
            HStack(alignment: .lastTextBaseline) {
                Text("today")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(summary.todayTokensText)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("input miss \(summary.todayInputMissText)")
                Text("input cache \(summary.todayInputCacheText)")
                Text("output \(summary.todayOutputText)")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
        }
        .padding(CGFloat(CodexWidgetLayoutMetrics.smallVerticalPadding))
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: CGFloat(CodexWidgetLayoutMetrics.mediumSectionSpacing)) {
            header
            HStack(spacing: 10) {
                limitBlock(summary.fiveHourLimitLabelText, summary.fiveHourLimitText, summary.fiveHourLimitPercent)
                limitBlock(summary.sevenDayLimitLabelText, summary.sevenDayLimitText, summary.sevenDayLimitPercent)
            }
            HStack(alignment: .top, spacing: 12) {
                tokenColumn(
                    "today",
                    total: summary.todayTokensText,
                    miss: summary.todayInputMissText,
                    cache: summary.todayInputCacheText,
                    output: summary.todayOutputText,
                    horizontalAlignment: .leading,
                    frameAlignment: .leading,
                    textAlignment: .leading
                )
                tokenColumn(
                    "week",
                    total: summary.thisWeekTokensText,
                    miss: summary.thisWeekInputMissText,
                    cache: summary.thisWeekInputCacheText,
                    output: summary.thisWeekOutputText,
                    horizontalAlignment: .trailing,
                    frameAlignment: .trailing,
                    textAlignment: .trailing
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, CGFloat(CodexWidgetLayoutMetrics.mediumVerticalPadding))
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "terminal")
                .font(.caption.weight(.semibold))
            Text("Codex")
                .font(.subheadline.weight(.semibold))
            Spacer(minLength: 0)
            Text(summary.planBadgeText)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private func limitBlock(_ title: String, _ value: String, _ percent: Double?) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer()
                Text(value)
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
            }
            usageProgress(percent)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }

    private func tokenColumn(
        _ title: String,
        total: String,
        miss: String,
        cache: String,
        output: String,
        horizontalAlignment: HorizontalAlignment,
        frameAlignment: Alignment,
        textAlignment: TextAlignment
    ) -> some View {
        VStack(alignment: horizontalAlignment, spacing: 2) {
            HStack(alignment: .lastTextBaseline, spacing: 5) {
                Text(total)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: frameAlignment)

            Text("input miss \(miss)")
            Text("input cache \(cache)")
            Text("output \(output)")
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(.secondary)
        .multilineTextAlignment(textAlignment)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .frame(maxWidth: .infinity, alignment: frameAlignment)
    }

    private func limitRow(_ title: String, _ value: String, _ percent: Double?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer()
                Text(value)
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
            }
            usageProgress(percent)
        }
    }

    private func normalized(_ percent: Double?) -> Double {
        min(max((percent ?? 0) / 100, 0), 1)
    }

    private func usageProgress(_ percent: Double?) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.tertiary)
                Capsule()
                    .fill(tint(for: percent))
                    .frame(width: geometry.size.width * normalized(percent))
            }
        }
        .frame(height: 6)
    }

    private func tint(for percent: Double?) -> Color {
        let value = percent ?? 0
        if value <= 10 {
            return .red
        }
        if value <= 30 {
            return .orange
        }
        return .green
    }
}

@main
struct CodexWatcherWidget: Widget {
    let kind = "CodexWatcherWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CodexUsageProvider()) { entry in
            CodexWatcherWidgetView(entry: entry)
        }
        .configurationDisplayName("Codex Watcher")
        .description("Track local Codex limits and token usage.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}
