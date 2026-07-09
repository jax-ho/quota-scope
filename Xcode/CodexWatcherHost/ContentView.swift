import SwiftUI
import WidgetKit

struct ContentView: View {
    private let metricColumns = [
        GridItem(.adaptive(minimum: 140), spacing: 16, alignment: .top)
    ]
    @State private var summary = CodexUsageSummary(snapshot: CodexUsageSnapshot())

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Image("QuotaScopeLogo")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .accessibilityHidden(true)
                    Text("QuotaScope")
                        .font(.title2.weight(.semibold))
                }
                Text("Add the WidgetKit widget from Notification Center on macOS 13, or from desktop Edit Widgets on macOS 14 and later.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 16) {
                metricCard("Plan", summary.planText)
                metricCard(summary.fiveHourLimitLabelText, summary.fiveHourLimitText)
                metricCard(summary.sevenDayLimitLabelText, summary.sevenDayLimitText)
                tokenCard(
                    "Today",
                    total: summary.todayTokensText,
                    miss: summary.todayInputMissText,
                    cache: summary.todayInputCacheText,
                    output: summary.todayOutputText
                )
                tokenCard(
                    "Week",
                    total: summary.thisWeekTokensText,
                    miss: summary.thisWeekInputMissText,
                    cache: summary.thisWeekInputCacheText,
                    output: summary.thisWeekOutputText
                )
                historyCard()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("How to add")
                    .font(.headline)
                Text("On macOS 13, open Notification Center, click Edit Widgets, search for QuotaScope, then add the widget. On macOS 14 or later, you can also drag it to the desktop from Edit Widgets.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Button("Reload Widget") {
                    Task {
                        await reload(reloadWidgets: true)
                    }
                }
                Spacer()
                Text(summary.updatedAtText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .task {
            await reload(reloadWidgets: false)
        }
    }

    @MainActor
    private func reload(reloadWidgets: Bool) async {
        let now = Date()
        let snapshot = CodexUsageLogStore.loadSnapshot(now: now)
        summary = CodexUsageSummary(snapshot: snapshot, now: now)
        if reloadWidgets {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func metricCard(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }

    private func tokenCard(_ title: String, total: String, miss: String, cache: String, output: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(total)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text("input miss \(miss)")
                .font(.caption.weight(.medium))
            Text("input cache \(cache)")
                .font(.caption.weight(.medium))
            Text("output \(output)")
                .font(.caption.weight(.medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func historyCard() -> some View {
        if !summary.weeklyBars.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Last 7 Days")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(Array(summary.weeklyBars.enumerated()), id: \.offset) { _, bar in
                    HStack {
                        Text(bar.label)
                            .font(.caption.weight(bar.isToday ? .semibold : .regular))
                            .foregroundStyle(bar.isToday ? .primary : .secondary)
                        Spacer()
                        Text(bar.valueText)
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        }
    }
}
