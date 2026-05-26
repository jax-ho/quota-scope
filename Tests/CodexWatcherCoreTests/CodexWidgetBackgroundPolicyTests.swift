import Foundation
import XCTest

final class CodexWidgetBackgroundPolicyTests: XCTestCase {
    func testWidgetBackgroundIsOnlyDeclaredAsWidgetContainerBackground() throws {
        let source = try widgetSource()

        XCTAssertTrue(
            source.contains(".containerBackground(for: .widget)"),
            "WidgetKit needs a container background so macOS can render desktop widget vibrancy correctly."
        )
        XCTAssertFalse(
            source.contains(".background {\n            WidgetBackground()"),
            "Do not render WidgetBackground as a normal SwiftUI background; macOS treats it as content in vibrant desktop states."
        )
    }

    func testDesktopWidgetKeepsContainerBackgroundInVibrantStates() throws {
        let source = try widgetSource()

        XCTAssertTrue(
            source.contains(".containerBackgroundRemovable(false)"),
            "QuotaScope relies on its card/background contrast, so macOS should fade the container background instead of removing it."
        )
    }

    func testWidgetAdaptsToSystemRenderingAndBackgroundVisibility() throws {
        let source = try widgetSource()

        XCTAssertTrue(
            source.contains("@Environment(\\.widgetRenderingMode)"),
            "Desktop widgets can render in accented or vibrant modes, so the view must adapt to WidgetKit's rendering mode."
        )
        XCTAssertTrue(
            source.contains("@Environment(\\.showsWidgetContainerBackground)"),
            "When macOS hides the widget container background, QuotaScope needs a high-contrast desktop palette instead of dark-mode foregrounds."
        )
        XCTAssertTrue(
            source.contains(".widgetAccentable()"),
            "Accent-colored quota content should be marked so WidgetKit can keep it visible in system-tinted rendering modes."
        )
    }

    func testDesktopRenderingPreservesDarkAppearanceWhenSystemIsDark() throws {
        let source = try widgetSource()

        XCTAssertFalse(
            source.contains("colorScheme == .dark && !usesDesktopTintedRendering"),
            "Desktop-tinted rendering should not force the dark widget into the light palette."
        )
        XCTAssertTrue(
            source.contains("return isDark ? Self.hex(0x171B21"),
            "The dark desktop-tinted container should keep the dark WidgetKit surface."
        )
    }

    func testLargeWidgetUsesFigmaDarkPaletteRegardlessOfDesktopColorScheme() throws {
        let source = try widgetSource()

        XCTAssertTrue(
            source.contains("forceDarkAppearance: renderedFamily == .systemLarge"),
            "The large widget should render the Figma night design even when macOS reports a light desktop color scheme."
        )
        XCTAssertTrue(source.contains("forceDarkAppearance ? ColorScheme.dark : colorScheme"))
    }

    func testContainerBackgroundUsesSameResolvedPaletteAsWidgetContent() throws {
        let source = try widgetSource()

        XCTAssertTrue(
            source.contains("let palette = resolvedPalette"),
            "Widget content and its container background should share one resolved palette."
        )
        XCTAssertTrue(
            source.contains("WidgetBackground(palette: palette, family: renderedFamily)"),
            "The WidgetKit container background must not fall back to the default light palette."
        )
    }

    func testQuotaResetTextUsesSameFontForFiveHourAndSevenDayCards() throws {
        let source = try widgetSource()

        XCTAssertFalse(
            source.contains("limit.tint == .fiveHour ?"),
            "The 7d reset line should not render smaller than the 5h reset line."
        )
    }

    func testLargeWidgetUsesFigmaQuotaCardDimensions() throws {
        let source = try widgetSource()

        XCTAssertTrue(source.contains("HStack(spacing: 8) {\n                QuotaCard(limit: summary.fiveHourQuotaLimit, style: .large)"))
        XCTAssertTrue(source.contains("QuotaCard(limit: summary.fiveHourQuotaLimit, style: .large)"))
        XCTAssertTrue(source.contains("QuotaCard(limit: summary.sevenDayQuotaLimit, style: .large)"))
        XCTAssertTrue(source.contains("case .large:"))
        XCTAssertTrue(source.contains("return CGSize(width: 148, height: 45)"))
    }

    func testLargeChartKeepsFigmaBottomGutter() throws {
        let source = try widgetSource()

        XCTAssertFalse(
            source.contains(".padding(.bottom, 4)"),
            "The large token chart labels should not sit too close to the panel bottom edge."
        )
        XCTAssertTrue(source.contains(".padding(.bottom, 20)"))
    }

    func testLargeWidgetUsesCompactFigmaVerticalRhythm() throws {
        let source = try widgetSource()

        XCTAssertFalse(source.contains(".frame(height: 21)\n\n            SectionTitle(\"Quota Overview\")"))
        XCTAssertFalse(source.contains(".frame(height: 18)\n\n            SectionTitle(\"Token Usage\")"))
        XCTAssertFalse(source.contains(".frame(height: 9)\n\n            SevenDayUsageChart(summary: summary)"))

        XCTAssertTrue(source.contains(".frame(height: 14)\n\n            SectionTitle(\"Quota Overview\")"))
        XCTAssertTrue(source.contains(".frame(height: 12)\n\n            SectionTitle(\"Token Usage\")"))
        XCTAssertTrue(source.contains(".frame(height: 7)\n\n            SevenDayUsageChart(summary: summary)"))
    }

    func testLargeTokenCardUsesCompactInternalRhythm() throws {
        let source = try widgetSource()

        XCTAssertFalse(source.contains("Spacer(minLength: 8)\n\n            ChartBars(bars: bars)"))
        XCTAssertTrue(source.contains(".padding(.top, 10)\n            .padding(.horizontal, 14)\n\n            CompactMCOSummary"))
        XCTAssertTrue(source.contains(".frame(width: 160, height: 11)\n                .padding(.top, 2)"))
        XCTAssertTrue(source.contains("Spacer(minLength: 2)\n\n            ChartBars(bars: bars)"))
    }

    func testBundleVersionsUseXcodeBuildSettingForCacheInvalidation() throws {
        let packageRoot = try packageRoot()
        let hostInfo = try String(
            contentsOf: packageRoot.appendingPathComponent("Xcode/CodexWatcherHost/Info.plist"),
            encoding: .utf8
        )
        let widgetInfo = try String(
            contentsOf: packageRoot.appendingPathComponent("Xcode/CodexWatcherWidget/Info.plist"),
            encoding: .utf8
        )
        let project = try String(
            contentsOf: packageRoot.appendingPathComponent("CodexWatcher.xcodeproj/project.pbxproj"),
            encoding: .utf8
        )

        XCTAssertTrue(hostInfo.contains("<string>$(CURRENT_PROJECT_VERSION)</string>"))
        XCTAssertTrue(widgetInfo.contains("<string>$(CURRENT_PROJECT_VERSION)</string>"))
        XCTAssertTrue(project.contains("CURRENT_PROJECT_VERSION = 7;"))
    }

    private func widgetSource() throws -> String {
        let packageRoot = try packageRoot()
        let widgetURL = packageRoot
            .appendingPathComponent("Xcode/CodexWatcherWidget/CodexWatcherWidget.swift")
        return try String(contentsOf: widgetURL, encoding: .utf8)
    }

    private func packageRoot() throws -> URL {
        let fileURL = URL(fileURLWithPath: #filePath)
        return fileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
