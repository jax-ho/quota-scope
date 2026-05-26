import XCTest
@testable import CodexWatcherCore

final class CodexUsageSummaryTests: XCTestCase {
    func testSummaryFormatsRemainingLimitAndTokenValuesForWidgets() throws {
        let snapshot = CodexUsageSnapshot(
            latestEvent: CodexUsageEvent(
                timestamp: Date(timeIntervalSince1970: 1_800),
                totalUsage: TokenUsage(inputTokens: 12_300_000, cachedInputTokens: 10_000_000, outputTokens: 45_000, reasoningOutputTokens: 2_000, totalTokens: 12_347_000),
                lastUsage: TokenUsage(totalTokens: 120_000),
                rateLimits: RateLimits(
                    primary: RateWindow(
                        usedPercent: 7.4,
                        windowMinutes: 300,
                        resetsAt: codexTestDate("2026-05-25T07:30:00.000Z")
                    ),
                    secondary: RateWindow(
                        usedPercent: 19.6,
                        windowMinutes: 10_080,
                        resetsAt: codexTestDate("2026-05-31T08:45:00.000Z")
                    ),
                    planType: "plus"
                )
            ),
            tokensLast5Hours: TokenUsage(totalTokens: 8_481_157),
            tokensLast7Days: TokenUsage(totalTokens: 176_629_938),
            tokensToday: TokenUsage(inputTokens: 3_200_000, cachedInputTokens: 2_100_000, outputTokens: 400_000, totalTokens: 3_600_000),
            tokensThisWeek: TokenUsage(inputTokens: 42_500_000, cachedInputTokens: 30_000_000, outputTokens: 5_250_000, totalTokens: 47_750_000),
            eventCount: 3254
        )

        let summary = CodexUsageSummary(
            snapshot: snapshot,
            now: try XCTUnwrap(codexTestDate("2026-05-25T04:20:00.000Z")),
            timeZone: TimeZone(secondsFromGMT: 8 * 60 * 60)!
        )

        XCTAssertEqual(summary.title, "Codex Watcher")
        XCTAssertEqual(summary.planText, "plus")
        XCTAssertEqual(summary.planBadgeText, "plan plus")
        XCTAssertEqual(summary.fiveHourLimitLabelText, "5h until 15:30")
        XCTAssertEqual(summary.sevenDayLimitLabelText, "7d until 05/31 16:45")
        XCTAssertEqual(summary.fiveHourLimitText, "93%")
        XCTAssertEqual(summary.sevenDayLimitText, "80%")
        XCTAssertEqual(summary.fiveHourLimitPercent, 92.6)
        XCTAssertEqual(summary.sevenDayLimitPercent, 80.4)
        XCTAssertEqual(summary.todayTokensText, "3.6M")
        XCTAssertEqual(summary.todayInputMissText, "1.1M")
        XCTAssertEqual(summary.todayInputCacheText, "2.1M")
        XCTAssertEqual(summary.todayOutputText, "400.0K")
        XCTAssertEqual(summary.thisWeekTokensText, "47.8M")
        XCTAssertEqual(summary.thisWeekInputMissText, "12.5M")
        XCTAssertEqual(summary.thisWeekInputCacheText, "30.0M")
        XCTAssertEqual(summary.thisWeekOutputText, "5.2M")
        XCTAssertFalse(summary.isEmpty)
    }

    func testEmptySummaryUsesPlaceholders() {
        let summary = CodexUsageSummary(snapshot: CodexUsageSnapshot())

        XCTAssertEqual(summary.fiveHourLimitLabelText, "5h remaining")
        XCTAssertEqual(summary.sevenDayLimitLabelText, "7d remaining")
        XCTAssertEqual(summary.fiveHourLimitText, "--")
        XCTAssertEqual(summary.sevenDayLimitText, "--")
        XCTAssertEqual(summary.planBadgeText, "plan --")
        XCTAssertEqual(summary.todayTokensText, "--")
        XCTAssertEqual(summary.todayInputMissText, "--")
        XCTAssertEqual(summary.todayInputCacheText, "--")
        XCTAssertEqual(summary.todayOutputText, "--")
        XCTAssertEqual(summary.thisWeekTokensText, "--")
        XCTAssertEqual(summary.thisWeekInputMissText, "--")
        XCTAssertEqual(summary.thisWeekInputCacheText, "--")
        XCTAssertEqual(summary.thisWeekOutputText, "--")
        XCTAssertTrue(summary.isEmpty)
    }
}
