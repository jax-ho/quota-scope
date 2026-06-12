import XCTest
@testable import CodexWatcherCore

final class CodexUsageAPIClientTests: XCTestCase {
    func testDecodesCodexUsageResponseIntoRateLimits() throws {
        let data = Data("""
        {
          "plan_type": "prolite",
          "rate_limit": {
            "allowed": true,
            "limit_reached": false,
            "primary_window": {
              "used_percent": 17,
              "limit_window_seconds": 18000,
              "reset_after_seconds": 15261,
              "reset_at": 1779697231
            },
            "secondary_window": {
              "used_percent": 10,
              "limit_window_seconds": 604800,
              "reset_after_seconds": 531884,
              "reset_at": 1780213854
            }
          }
        }
        """.utf8)

        let rateLimits = try CodexUsageAPIResponse.decodeRateLimits(from: data)

        XCTAssertEqual(rateLimits.planType, "prolite")
        XCTAssertEqual(rateLimits.primary?.usedPercent, 17)
        XCTAssertEqual(rateLimits.primary?.windowMinutes, 300)
        XCTAssertEqual(rateLimits.primary?.resetsAt, Date(timeIntervalSince1970: 1_779_697_231))
        XCTAssertEqual(rateLimits.secondary?.usedPercent, 10)
        XCTAssertEqual(rateLimits.secondary?.windowMinutes, 10_080)
        XCTAssertEqual(rateLimits.secondary?.resetsAt, Date(timeIntervalSince1970: 1_780_213_854))
    }

    func testAPILimitsOverrideLocalLogLimitsWhileTokenTotalsStayLocal() async throws {
        let now = try XCTUnwrap(codexTestDate("2026-05-25T04:20:00.000Z"))
        let localSnapshot = CodexUsageSnapshot(
            latestEvent: CodexUsageEvent(
                timestamp: now.addingTimeInterval(-120),
                rateLimits: RateLimits(
                    primary: RateWindow(usedPercent: 2, windowMinutes: 300),
                    secondary: RateWindow(usedPercent: 8, windowMinutes: 10_080),
                    planType: "stale"
                )
            ),
            rateLimits: RateLimits(
                primary: RateWindow(usedPercent: 2, windowMinutes: 300),
                secondary: RateWindow(usedPercent: 8, windowMinutes: 10_080),
                planType: "stale"
            ),
            tokensToday: TokenUsage(inputTokens: 1_000_000, cachedInputTokens: 700_000, outputTokens: 42_000, totalTokens: 1_042_000),
            tokensThisWeek: TokenUsage(inputTokens: 7_000_000, cachedInputTokens: 4_000_000, outputTokens: 600_000, totalTokens: 7_600_000),
            eventCount: 12
        )
        let apiRateLimits = RateLimits(
            primary: RateWindow(usedPercent: 17, windowMinutes: 300),
            secondary: RateWindow(usedPercent: 10, windowMinutes: 10_080),
            planType: "prolite"
        )

        let snapshot = CodexUsageAPIClient.apply(
            apiRateLimits: apiRateLimits,
            to: localSnapshot,
            now: now
        )

        XCTAssertEqual(snapshot.rateLimits, apiRateLimits)
        XCTAssertEqual(snapshot.latestEvent?.timestamp, now)
        XCTAssertEqual(snapshot.latestEvent?.rateLimits, apiRateLimits)
        XCTAssertEqual(snapshot.tokensToday.totalTokens, 1_042_000)
        XCTAssertEqual(snapshot.tokensToday.cachedInputTokens, 700_000)
        XCTAssertEqual(snapshot.tokensThisWeek.totalTokens, 7_600_000)

        let summary = CodexUsageSummary(snapshot: snapshot, now: now)
        XCTAssertEqual(summary.fiveHourLimitText, "83%")
        XCTAssertEqual(summary.sevenDayLimitText, "90%")
        XCTAssertEqual(summary.todayTokensText, "1.0M")
        XCTAssertEqual(summary.planText, "prolite")
    }

    func testSnapshotWithoutFreshAPIDataStripsLocalLogLimits() throws {
        let now = try XCTUnwrap(codexTestDate("2026-05-25T04:20:00.000Z"))
        let localSnapshot = CodexUsageSnapshot(
            latestEvent: CodexUsageEvent(
                timestamp: now,
                rateLimits: RateLimits(primary: RateWindow(usedPercent: 2, windowMinutes: 300), planType: "stale")
            ),
            rateLimits: RateLimits(primary: RateWindow(usedPercent: 2, windowMinutes: 300), planType: "stale"),
            tokensToday: TokenUsage(totalTokens: 1_000_000),
            eventCount: 1
        )

        let snapshot = CodexUsageAPIClient.removingLocalRateLimits(from: localSnapshot)

        XCTAssertNil(snapshot.rateLimits)
        XCTAssertNil(snapshot.latestEvent?.rateLimits)
        XCTAssertEqual(snapshot.tokensToday.totalTokens, 1_000_000)
        XCTAssertEqual(CodexUsageSummary(snapshot: snapshot, now: now).fiveHourLimitText, "--")
    }

    func testLoadSnapshotFallsBackToLocalLogLimitsWhenAPIFetchFails() async throws {
        let now = try XCTUnwrap(codexTestDate("2026-05-25T04:20:00.000Z"))
        let missingCodexHome = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodexWatcherTests-missing-auth-\(UUID().uuidString)")
        let localRateLimits = RateLimits(
            primary: RateWindow(usedPercent: 72, windowMinutes: 300),
            secondary: RateWindow(usedPercent: 28, windowMinutes: 10_080),
            planType: "prolite"
        )
        let localSnapshot = CodexUsageSnapshot(
            latestEvent: CodexUsageEvent(
                timestamp: now.addingTimeInterval(-60),
                rateLimits: localRateLimits
            ),
            rateLimits: localRateLimits,
            tokensToday: TokenUsage(totalTokens: 1_000_000),
            eventCount: 1
        )
        let client = CodexUsageAPIClient(
            authStore: CodexAuthStore(codexHome: missingCodexHome),
            cache: CodexUsageAPIRateLimitCache(url: nil)
        )

        let snapshot = await client.loadSnapshot(localSnapshot: localSnapshot, now: now)

        XCTAssertEqual(snapshot.rateLimits, localRateLimits)
        XCTAssertEqual(snapshot.latestEvent?.rateLimits, localRateLimits)
        XCTAssertEqual(snapshot.tokensToday.totalTokens, 1_000_000)

        let summary = CodexUsageSummary(snapshot: snapshot, now: now)
        XCTAssertEqual(summary.planText, "prolite")
        XCTAssertEqual(summary.fiveHourLimitText, "28%")
        XCTAssertEqual(summary.sevenDayLimitText, "72%")
    }
}
