import SwiftUI
import WidgetKit

struct ContentView: View {
    private let apiClient = CodexUsageAPIClient()
    private let metricColumns = [
        GridItem(.adaptive(minimum: 140), spacing: 16, alignment: .top)
    ]
    @State private var summary = CodexUsageSummary(
        snapshot: CodexUsageAPIClient.removingLocalRateLimits(from: CodexUsageLogStore.loadSnapshot())
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Codex Watcher")
                    .font(.title2.weight(.semibold))
                Text("Add the WidgetKit widget from macOS Edit Widgets, then drag it to your desktop.")
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
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("How to add")
                    .font(.headline)
                Text("Control-click the desktop wallpaper, choose Edit Widgets, search for Codex Watcher, then drag the widget to the desktop.")
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
        let snapshot = await apiClient.loadSnapshot(now: now)
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
}
