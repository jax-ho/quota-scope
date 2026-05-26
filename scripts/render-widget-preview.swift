import AppKit
import Foundation
import SwiftUI

private struct PreviewRoot: View {
    let summary: CodexUsageSummary

    var body: some View {
        HStack(spacing: 28) {
            WidgetSmall(summary: summary)
                .frame(width: 170, height: 170)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            WidgetMedium(summary: summary)
                .frame(width: 344, height: 164)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .padding(34)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.19, green: 0.21, blue: 0.24),
                    Color(red: 0.11, green: 0.12, blue: 0.14)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

private struct WidgetSmall: View {
    let summary: CodexUsageSummary

    var body: some View {
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
                    .foregroundStyle(.primary)
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
        }
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
}

private struct WidgetMedium: View {
    let summary: CodexUsageSummary

    var body: some View {
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
                .fill(usageTint(for: percent))
                .frame(width: geometry.size.width * normalized(percent))
        }
    }
    .frame(height: 6)
}

private func usageTint(for percent: Double?) -> Color {
    let value = percent ?? 0
    if value <= 10 {
        return .red
    }
    if value <= 30 {
        return .orange
    }
    return .green
}

@main
struct RenderWidgetPreview {
    @MainActor
    static func main() async throws {
        let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
        let snapshot = await CodexUsageAPIClient().loadSnapshot()
        let summary = CodexUsageSummary(snapshot: snapshot)
        let renderer = ImageRenderer(content: PreviewRoot(summary: summary))
        renderer.scale = 2

        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "CodexWatcherPreview", code: 1)
        }

        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try png.write(to: outputURL)
        print(outputURL.path)
    }
}
