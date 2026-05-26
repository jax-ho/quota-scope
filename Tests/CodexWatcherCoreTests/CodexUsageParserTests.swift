import XCTest
@testable import CodexWatcherCore

final class CodexUsageParserTests: XCTestCase {
    func testParseTokenCountEventWithRateLimits() throws {
        let line = """
        {"timestamp":"2026-04-01T14:05:42.196Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":568016,"cached_input_tokens":443520,"output_tokens":7832,"reasoning_output_tokens":4156,"total_tokens":575848},"last_token_usage":{"input_tokens":76345,"cached_input_tokens":74752,"output_tokens":2852,"reasoning_output_tokens":1552,"total_tokens":79197},"model_context_window":258400},"rate_limits":{"primary":{"used_percent":10.0,"window_minutes":300,"resets_at":1775068080},"secondary":{"used_percent":3.0,"window_minutes":10080,"resets_at":1775634800},"plan_type":"plus"}}}
        """

        let event = try XCTUnwrap(CodexUsageParser.parseLine(line))

        XCTAssertEqual(event.timestamp, codexTestDate("2026-04-01T14:05:42.196Z"))
        XCTAssertEqual(event.totalUsage.totalTokens, 575_848)
        XCTAssertEqual(event.totalUsage.cachedInputTokens, 443_520)
        XCTAssertEqual(event.lastUsage.outputTokens, 2_852)
        XCTAssertEqual(event.lastUsage.reasoningOutputTokens, 1_552)
        XCTAssertEqual(event.modelContextWindow, 258_400)
        XCTAssertEqual(event.rateLimits?.primary?.usedPercent, 10.0)
        XCTAssertEqual(event.rateLimits?.primary?.windowMinutes, 300)
        XCTAssertEqual(event.rateLimits?.secondary?.usedPercent, 3.0)
        XCTAssertEqual(event.rateLimits?.secondary?.windowMinutes, 10_080)
        XCTAssertEqual(event.rateLimits?.planType, "plus")
    }

    func testIgnoresNonTokenCountAndMalformedLines() {
        XCTAssertNil(CodexUsageParser.parseLine(""))
        XCTAssertNil(CodexUsageParser.parseLine("{not-json"))
        XCTAssertNil(CodexUsageParser.parseLine(#"{"timestamp":"2026-04-01T14:05:42.196Z","type":"event_msg","payload":{"type":"note"}}"#))
    }

    func testSnapshotUsesLatestEventAndSumsRollingWindows() throws {
        let now = try XCTUnwrap(codexTestDate("2026-05-24T08:00:00.000Z"))
        let latest = CodexUsageEvent(
            timestamp: now,
            totalUsage: TokenUsage(inputTokens: 100, cachedInputTokens: 10, outputTokens: 20, reasoningOutputTokens: 3, totalTokens: 123),
            lastUsage: TokenUsage(inputTokens: 11, cachedInputTokens: 1, outputTokens: 2, reasoningOutputTokens: 1, totalTokens: 14),
            rateLimits: RateLimits(primary: RateWindow(usedPercent: 8, windowMinutes: 300), secondary: RateWindow(usedPercent: 20, windowMinutes: 10_080), planType: "pro")
        )
        let oneHourAgo = CodexUsageEvent(
            timestamp: now.addingTimeInterval(-3_600),
            lastUsage: TokenUsage(inputTokens: 5, cachedInputTokens: 2, outputTokens: 1, reasoningOutputTokens: 0, totalTokens: 6)
        )
        let sixHoursAgo = CodexUsageEvent(
            timestamp: now.addingTimeInterval(-21_600),
            lastUsage: TokenUsage(inputTokens: 7, cachedInputTokens: 3, outputTokens: 1, reasoningOutputTokens: 1, totalTokens: 9)
        )
        let eightDaysAgo = CodexUsageEvent(
            timestamp: now.addingTimeInterval(-691_200),
            lastUsage: TokenUsage(inputTokens: 99, cachedInputTokens: 99, outputTokens: 99, reasoningOutputTokens: 99, totalTokens: 99)
        )

        let snapshot = CodexUsageParser.makeSnapshot(
            events: [sixHoursAgo, latest, eightDaysAgo, oneHourAgo],
            now: now
        )

        XCTAssertEqual(snapshot.latestEvent, latest)
        XCTAssertEqual(snapshot.tokensLast5Hours.totalTokens, 20)
        XCTAssertEqual(snapshot.tokensLast5Hours.inputTokens, 16)
        XCTAssertEqual(snapshot.tokensLast7Days.totalTokens, 29)
        XCTAssertEqual(snapshot.tokensLast7Days.reasoningOutputTokens, 2)
        XCTAssertEqual(snapshot.eventCount, 4)
    }

    func testSnapshotSumsTodayAndCurrentIsoWeekTokens() throws {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let now = try XCTUnwrap(codexTestDate("2026-05-24T08:00:00.000Z"))
        let today = CodexUsageEvent(
            timestamp: try XCTUnwrap(codexTestDate("2026-05-24T01:00:00.000Z")),
            lastUsage: TokenUsage(inputTokens: 10, cachedInputTokens: 2, outputTokens: 3, reasoningOutputTokens: 1, totalTokens: 14)
        )
        let yesterdaySameWeek = CodexUsageEvent(
            timestamp: try XCTUnwrap(codexTestDate("2026-05-23T23:00:00.000Z")),
            lastUsage: TokenUsage(inputTokens: 20, cachedInputTokens: 4, outputTokens: 6, reasoningOutputTokens: 2, totalTokens: 28)
        )
        let previousWeek = CodexUsageEvent(
            timestamp: try XCTUnwrap(codexTestDate("2026-05-17T23:59:59.000Z")),
            lastUsage: TokenUsage(inputTokens: 99, cachedInputTokens: 99, outputTokens: 99, reasoningOutputTokens: 99, totalTokens: 99)
        )

        let snapshot = CodexUsageParser.makeSnapshot(
            events: [previousWeek, yesterdaySameWeek, today],
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.tokensToday.totalTokens, 14)
        XCTAssertEqual(snapshot.tokensToday.inputTokens, 10)
        XCTAssertEqual(snapshot.tokensToday.cachedInputTokens, 2)
        XCTAssertEqual(snapshot.tokensToday.outputTokens, 3)
        XCTAssertEqual(snapshot.tokensThisWeek.totalTokens, 42)
        XCTAssertEqual(snapshot.tokensThisWeek.cachedInputTokens, 6)
        XCTAssertEqual(snapshot.tokensThisWeek.outputTokens, 9)
        XCTAssertEqual(snapshot.tokensThisWeek.reasoningOutputTokens, 3)
    }

    func testSnapshotBuildsDailyUsageForLastSevenCalendarDays() throws {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let now = try XCTUnwrap(codexTestDate("2026-05-24T08:00:00.000Z"))
        let todayMorning = CodexUsageEvent(
            timestamp: try XCTUnwrap(codexTestDate("2026-05-24T01:00:00.000Z")),
            lastUsage: TokenUsage(inputTokens: 10, cachedInputTokens: 2, outputTokens: 3, totalTokens: 14)
        )
        let todayLater = CodexUsageEvent(
            timestamp: try XCTUnwrap(codexTestDate("2026-05-24T07:00:00.000Z")),
            lastUsage: TokenUsage(inputTokens: 20, cachedInputTokens: 4, outputTokens: 6, totalTokens: 28)
        )
        let sixDaysAgo = CodexUsageEvent(
            timestamp: try XCTUnwrap(codexTestDate("2026-05-18T23:00:00.000Z")),
            lastUsage: TokenUsage(inputTokens: 30, cachedInputTokens: 6, outputTokens: 9, totalTokens: 42)
        )
        let sevenDaysAgo = CodexUsageEvent(
            timestamp: try XCTUnwrap(codexTestDate("2026-05-17T23:59:59.000Z")),
            lastUsage: TokenUsage(inputTokens: 99, cachedInputTokens: 99, outputTokens: 99, totalTokens: 99)
        )

        let snapshot = CodexUsageParser.makeSnapshot(
            events: [sevenDaysAgo, todayMorning, sixDaysAgo, todayLater],
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.dailyUsageLast7Days.map(\.date), [
            try XCTUnwrap(codexTestDate("2026-05-18T00:00:00.000Z")),
            try XCTUnwrap(codexTestDate("2026-05-19T00:00:00.000Z")),
            try XCTUnwrap(codexTestDate("2026-05-20T00:00:00.000Z")),
            try XCTUnwrap(codexTestDate("2026-05-21T00:00:00.000Z")),
            try XCTUnwrap(codexTestDate("2026-05-22T00:00:00.000Z")),
            try XCTUnwrap(codexTestDate("2026-05-23T00:00:00.000Z")),
            try XCTUnwrap(codexTestDate("2026-05-24T00:00:00.000Z"))
        ])
        XCTAssertEqual(snapshot.dailyUsageLast7Days.map { $0.usage.totalTokens }, [42, 0, 0, 0, 0, 0, 42])
        XCTAssertEqual(snapshot.dailyUsageLast7Days.last?.usage.inputTokens, 30)
        XCTAssertEqual(snapshot.dailyUsageLast7Days.last?.usage.cachedInputTokens, 6)
        XCTAssertEqual(snapshot.dailyUsageLast7Days.last?.usage.outputTokens, 9)
    }

    func testSnapshotUsesMostConservativeRecentRateLimitAcrossConcurrentSessions() throws {
        let now = try XCTUnwrap(codexTestDate("2026-05-25T04:00:00.000Z"))
        let lowerUsedNewer = CodexUsageEvent(
            timestamp: now.addingTimeInterval(-30),
            rateLimits: RateLimits(
                primary: RateWindow(usedPercent: 2, windowMinutes: 300),
                secondary: RateWindow(usedPercent: 8, windowMinutes: 10_080),
                planType: "prolite"
            )
        )
        let higherUsedOlder = CodexUsageEvent(
            timestamp: now.addingTimeInterval(-60),
            rateLimits: RateLimits(
                primary: RateWindow(usedPercent: 11, windowMinutes: 300),
                secondary: RateWindow(usedPercent: 9, windowMinutes: 10_080),
                planType: "prolite"
            )
        )
        let staleHigher = CodexUsageEvent(
            timestamp: now.addingTimeInterval(-20 * 60),
            rateLimits: RateLimits(
                primary: RateWindow(usedPercent: 50, windowMinutes: 300),
                secondary: RateWindow(usedPercent: 50, windowMinutes: 10_080),
                planType: "prolite"
            )
        )

        let snapshot = CodexUsageParser.makeSnapshot(
            events: [staleHigher, higherUsedOlder, lowerUsedNewer],
            now: now
        )

        XCTAssertEqual(snapshot.rateLimits?.primary?.usedPercent, 11)
        XCTAssertEqual(snapshot.rateLimits?.secondary?.usedPercent, 9)

        let summary = CodexUsageSummary(snapshot: snapshot, now: now)
        XCTAssertEqual(summary.fiveHourLimitText, "89%")
        XCTAssertEqual(summary.sevenDayLimitText, "91%")
    }
}

func codexTestDate(_ value: String) -> Date? {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.date(from: value)
}
