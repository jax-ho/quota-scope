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

        XCTAssertEqual(summary.title, "QuotaScope")
        XCTAssertEqual(summary.planText, "plus")
        XCTAssertEqual(summary.planBadgeText, "plus")
        XCTAssertEqual(summary.fiveHourLimitLabelText, "5h remaining")
        XCTAssertEqual(summary.fiveHourResetText, "until 15:30")
        XCTAssertEqual(summary.sevenDayLimitLabelText, "7d remaining")
        XCTAssertEqual(summary.sevenDayResetText, "until 05/31 16:45")
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
        XCTAssertEqual(summary.weekSummaryText, "Week 47.8M")
        XCTAssertFalse(summary.isEmpty)
    }

    func testQuotaScopeSampleSummaryMatchesFigmaWidgetContent() throws {
        let timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 8 * 60 * 60))
        let now = try XCTUnwrap(codexTestDate("2026-05-26T04:42:00.000Z"))
        let snapshot = CodexUsageSnapshot(
            latestEvent: CodexUsageEvent(
                timestamp: now,
                rateLimits: RateLimits(
                    primary: RateWindow(
                        usedPercent: 38,
                        windowMinutes: 300,
                        resetsAt: try XCTUnwrap(codexTestDate("2026-05-26T08:20:00.000Z"))
                    ),
                    secondary: RateWindow(
                        usedPercent: 19,
                        windowMinutes: 10_080,
                        resetsAt: try XCTUnwrap(codexTestDate("2026-05-31T07:50:00.000Z"))
                    ),
                    planType: "prolite"
                )
            ),
            tokensToday: TokenUsage(inputTokens: 129_800, cachedInputTokens: 91_600, outputTokens: 26_400, totalTokens: 128_400),
            tokensThisWeek: TokenUsage(inputTokens: 727_100, cachedInputTokens: 512_300, outputTokens: 85_600, totalTokens: 812_700),
            dailyUsageLast7Days: [
                CodexDailyUsage(date: try XCTUnwrap(codexTestDate("2026-05-20T12:00:00.000Z")), usage: TokenUsage(totalTokens: 90_000)),
                CodexDailyUsage(date: try XCTUnwrap(codexTestDate("2026-05-21T12:00:00.000Z")), usage: TokenUsage(totalTokens: 112_000)),
                CodexDailyUsage(date: try XCTUnwrap(codexTestDate("2026-05-22T12:00:00.000Z")), usage: TokenUsage(totalTokens: 98_000)),
                CodexDailyUsage(date: try XCTUnwrap(codexTestDate("2026-05-23T12:00:00.000Z")), usage: TokenUsage(totalTokens: 128_000)),
                CodexDailyUsage(date: try XCTUnwrap(codexTestDate("2026-05-24T12:00:00.000Z")), usage: TokenUsage(totalTokens: 76_000)),
                CodexDailyUsage(date: try XCTUnwrap(codexTestDate("2026-05-25T12:00:00.000Z")), usage: TokenUsage(totalTokens: 134_000)),
                CodexDailyUsage(date: try XCTUnwrap(codexTestDate("2026-05-26T04:42:00.000Z")), usage: TokenUsage(totalTokens: 128_400))
            ]
        )

        let summary = CodexUsageSummary(snapshot: snapshot, now: now, timeZone: timeZone)

        XCTAssertEqual(summary.title, "QuotaScope")
        XCTAssertEqual(summary.planText, "prolite")
        XCTAssertEqual(summary.planBadgeText, "prolite")
        XCTAssertEqual(summary.fiveHourLimitLabelText, "5h remaining")
        XCTAssertEqual(summary.fiveHourLimitText, "62%")
        XCTAssertEqual(summary.fiveHourResetText, "until 16:20")
        XCTAssertEqual(summary.sevenDayLimitLabelText, "7d remaining")
        XCTAssertEqual(summary.sevenDayLimitText, "81%")
        XCTAssertEqual(summary.sevenDayResetText, "until 05/31 15:50")
        XCTAssertEqual(summary.todayTokensText, "128.4K")
        XCTAssertEqual(summary.todayInputMissText, "38.2K")
        XCTAssertEqual(summary.todayInputCacheText, "91.6K")
        XCTAssertEqual(summary.todayOutputText, "26.4K")
        XCTAssertEqual(summary.thisWeekTokensText, "812.7K")
        XCTAssertEqual(summary.weekSummaryText, "Week 812.7K")
        XCTAssertEqual(summary.updatedAtText, "Updated 12:42")
        XCTAssertEqual(summary.weeklyBars.map(\.label), ["Wed", "Thu", "Fri", "Sat", "Sun", "Mon", "Today"])
        XCTAssertEqual(summary.weeklyBars.last?.valueText, "128K")
        XCTAssertEqual(summary.weeklyBars.last?.isToday, true)
        XCTAssertEqual(summary.weeklyBars.map(\.normalizedHeight).max(), 1)
    }

    func testEmptySummaryUsesPlaceholders() {
        let summary = CodexUsageSummary(snapshot: CodexUsageSnapshot())

        XCTAssertEqual(summary.fiveHourLimitLabelText, "5h remaining")
        XCTAssertEqual(summary.sevenDayLimitLabelText, "7d remaining")
        XCTAssertEqual(summary.fiveHourResetText, "--")
        XCTAssertEqual(summary.sevenDayResetText, "--")
        XCTAssertEqual(summary.fiveHourLimitText, "--")
        XCTAssertEqual(summary.sevenDayLimitText, "--")
        XCTAssertEqual(summary.planBadgeText, "--")
        XCTAssertEqual(summary.todayTokensText, "--")
        XCTAssertEqual(summary.todayInputMissText, "--")
        XCTAssertEqual(summary.todayInputCacheText, "--")
        XCTAssertEqual(summary.todayOutputText, "--")
        XCTAssertEqual(summary.thisWeekTokensText, "--")
        XCTAssertEqual(summary.thisWeekInputMissText, "--")
        XCTAssertEqual(summary.thisWeekInputCacheText, "--")
        XCTAssertEqual(summary.thisWeekOutputText, "--")
        XCTAssertEqual(summary.weekSummaryText, "Week --")
        XCTAssertEqual(summary.weeklyBars.count, 0)
        XCTAssertTrue(summary.isEmpty)
    }

    func testAPISnapshotWithoutTokenUsageUsesTokenPlaceholders() throws {
        let now = try XCTUnwrap(codexTestDate("2026-05-25T04:20:00.000Z"))
        let snapshot = CodexUsageSnapshot(
            latestEvent: CodexUsageEvent(
                timestamp: now,
                rateLimits: RateLimits(
                    primary: RateWindow(usedPercent: 17, windowMinutes: 300),
                    secondary: RateWindow(usedPercent: 10, windowMinutes: 10_080),
                    planType: "prolite"
                )
            ),
            rateLimits: RateLimits(
                primary: RateWindow(usedPercent: 17, windowMinutes: 300),
                secondary: RateWindow(usedPercent: 10, windowMinutes: 10_080),
                planType: "prolite"
            )
        )

        let summary = CodexUsageSummary(snapshot: snapshot, now: now)

        XCTAssertEqual(summary.planText, "prolite")
        XCTAssertEqual(summary.fiveHourLimitText, "83%")
        XCTAssertEqual(summary.sevenDayLimitText, "90%")
        XCTAssertEqual(summary.todayTokensText, "--")
        XCTAssertEqual(summary.todayInputMissText, "--")
        XCTAssertEqual(summary.todayInputCacheText, "--")
        XCTAssertEqual(summary.todayOutputText, "--")
        XCTAssertEqual(summary.thisWeekTokensText, "--")
        XCTAssertEqual(summary.weekSummaryText, "Week --")
        XCTAssertEqual(summary.weeklyBars, [])
        XCTAssertFalse(summary.isEmpty)
    }
}
