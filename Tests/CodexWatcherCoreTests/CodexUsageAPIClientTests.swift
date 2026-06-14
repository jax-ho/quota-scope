import XCTest
@testable import CodexWatcherCore

final class CodexUsageAPIClientTests: XCTestCase {
    func testDefaultUsageEndpointUsesWhamAPIWithCodexFallback() {
        XCTAssertEqual(
            CodexUsageAPIClient.defaultUsageURL.absoluteString,
            "https://chatgpt.com/backend-api/wham/usage"
        )
        XCTAssertEqual(
            CodexUsageAPIClient.defaultFallbackUsageURLs.map(\.absoluteString),
            ["https://chatgpt.com/backend-api/codex/usage"]
        )
    }

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

    func testLoadSnapshotUsesLocalTokenTotalsWithAPIRateLimits() async throws {
        let now = try XCTUnwrap(codexTestDate("2026-05-25T04:20:00.000Z"))
        let codexHome = try makeCodexHomeWithAuthAndLocalUsage()
        defer {
            try? FileManager.default.removeItem(at: codexHome)
        }
        let client = CodexUsageAPIClient(
            authStore: CodexAuthStore(codexHome: codexHome),
            cache: CodexUsageAPIRateLimitCache(url: nil),
            profileLoader: EmptyCodexUsageProfileLoader(),
            httpClient: StubHTTPClient(data: codexUsageAPIResponseData())
        )

        let snapshot = await client.loadSnapshot(now: now)

        XCTAssertEqual(snapshot.rateLimits?.planType, "prolite")
        XCTAssertEqual(snapshot.rateLimits?.primary?.usedPercent, 17)
        XCTAssertEqual(snapshot.rateLimits?.secondary?.usedPercent, 10)
        XCTAssertEqual(snapshot.latestEvent?.timestamp, now)
        XCTAssertEqual(snapshot.latestEvent?.rateLimits, snapshot.rateLimits)
        XCTAssertEqual(snapshot.tokensToday.totalTokens, 1_042_000)
        XCTAssertEqual(snapshot.tokensToday.cachedInputTokens, 700_000)
        XCTAssertEqual(snapshot.tokensThisWeek.totalTokens, 1_042_000)
        XCTAssertEqual(snapshot.dailyUsageLast7Days.count, 7)
        XCTAssertEqual(snapshot.dailyUsageLast7Days.last?.usage.totalTokens, 1_042_000)
        XCTAssertEqual(snapshot.eventCount, 1)

        let summary = CodexUsageSummary(snapshot: snapshot, now: now)
        XCTAssertEqual(summary.fiveHourLimitText, "83%")
        XCTAssertEqual(summary.sevenDayLimitText, "90%")
        XCTAssertEqual(summary.todayTokensText, "1.0M")
        XCTAssertEqual(summary.planText, "prolite")
    }

    func testLoadSnapshotUsesLocalTodayAndAPIHistoricalBuckets() async throws {
        let now = try XCTUnwrap(codexTestDate("2026-06-14T12:00:00.000Z"))
        let codexHome = try makeCodexHomeWithAuthAndLocalUsage(
            eventLines: [
                """
                {"timestamp":"2026-06-13T10:00:00.000Z","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":999000000,"cached_input_tokens":0,"output_tokens":0,"total_tokens":999000000}}}}
                """,
                """
                {"timestamp":"2026-06-14T10:00:00.000Z","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":30000000,"cached_input_tokens":10000000,"output_tokens":20000000,"total_tokens":50000000}}}}
                """
            ]
        )
        defer {
            try? FileManager.default.removeItem(at: codexHome)
        }
        let profile = CodexUsageProfile(
            tokensToday: TokenUsage(totalTokens: 3_692_822),
            tokensThisWeek: TokenUsage(totalTokens: 265_154_075),
            dailyUsageLast7Days: [
                CodexDailyUsage(date: try XCTUnwrap(codexTestDate("2026-06-08T10:00:00.000Z")), usage: TokenUsage(totalTokens: 27_974_994)),
                CodexDailyUsage(date: try XCTUnwrap(codexTestDate("2026-06-09T10:00:00.000Z")), usage: TokenUsage(totalTokens: 126_395_029)),
                CodexDailyUsage(date: try XCTUnwrap(codexTestDate("2026-06-10T10:00:00.000Z")), usage: TokenUsage(totalTokens: 6_588_974)),
                CodexDailyUsage(date: try XCTUnwrap(codexTestDate("2026-06-11T10:00:00.000Z")), usage: TokenUsage(totalTokens: 35_779_928)),
                CodexDailyUsage(date: try XCTUnwrap(codexTestDate("2026-06-12T10:00:00.000Z")), usage: TokenUsage(totalTokens: 49_044_300)),
                CodexDailyUsage(date: try XCTUnwrap(codexTestDate("2026-06-13T10:00:00.000Z")), usage: TokenUsage(totalTokens: 15_678_028)),
                CodexDailyUsage(date: try XCTUnwrap(codexTestDate("2026-06-14T10:00:00.000Z")), usage: TokenUsage(totalTokens: 3_692_822))
            ]
        )
        let client = CodexUsageAPIClient(
            authStore: CodexAuthStore(codexHome: codexHome),
            cache: CodexUsageAPIRateLimitCache(url: nil),
            profileLoader: StubUsageProfileLoader(profile: profile),
            httpClient: StubHTTPClient(data: codexUsageAPIResponseData())
        )

        let snapshot = await client.loadSnapshot(codexHome: codexHome, now: now)

        XCTAssertEqual(snapshot.rateLimits?.planType, "prolite")
        XCTAssertEqual(snapshot.tokensToday.totalTokens, 50_000_000)
        XCTAssertEqual(snapshot.tokensToday.inputTokens, 30_000_000)
        XCTAssertEqual(snapshot.tokensToday.cachedInputTokens, 10_000_000)
        XCTAssertEqual(snapshot.tokensToday.outputTokens, 20_000_000)
        XCTAssertEqual(snapshot.tokensThisWeek.totalTokens, 311_461_253)
        XCTAssertEqual(snapshot.tokensThisWeek.cachedInputTokens, 10_000_000)
        XCTAssertEqual(snapshot.dailyUsageLast7Days.map(\.usage.totalTokens), [
            27_974_994,
            126_395_029,
            6_588_974,
            35_779_928,
            49_044_300,
            15_678_028,
            50_000_000
        ])
        XCTAssertEqual(snapshot.eventCount, 2)
    }

    func testApplyMergesAPIRateLimitsWithLocalTokenTotals() throws {
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
        XCTAssertEqual(snapshot.tokensThisWeek.totalTokens, 7_600_000)
        XCTAssertEqual(snapshot.eventCount, 12)
    }

    func testFetchRateLimitsFallsBackToCodexEndpointWhenPrimaryFails() async throws {
        let now = try XCTUnwrap(codexTestDate("2026-05-25T04:20:00.000Z"))
        let codexHome = try makeCodexHomeWithAuthAndLocalUsage()
        defer {
            try? FileManager.default.removeItem(at: codexHome)
        }
        let httpClient = SequencedHTTPClient(responses: [
            StubHTTPResponse(data: Data(#"{"error":"forbidden"}"#.utf8), statusCode: 403),
            StubHTTPResponse(data: codexUsageAPIResponseData(), statusCode: 200)
        ])
        let client = CodexUsageAPIClient(
            authStore: CodexAuthStore(codexHome: codexHome),
            usageURL: URL(string: "https://chatgpt.com/backend-api/wham/usage")!,
            fallbackUsageURLs: [URL(string: "https://chatgpt.com/backend-api/codex/usage")!],
            cache: CodexUsageAPIRateLimitCache(url: nil),
            profileLoader: EmptyCodexUsageProfileLoader(),
            httpClient: httpClient
        )

        let snapshot = await client.loadSnapshot(codexHome: codexHome, now: now)

        XCTAssertEqual(snapshot.rateLimits?.planType, "prolite")
        XCTAssertEqual(httpClient.requestedURLs.map(\.absoluteString), [
            "https://chatgpt.com/backend-api/wham/usage",
            "https://chatgpt.com/backend-api/codex/usage"
        ])
    }

    func testLoadSnapshotKeepsLocalTokenTotalsWhenAPIFetchFailsWithoutCachedAPIData() async throws {
        let now = try XCTUnwrap(codexTestDate("2026-05-25T04:20:00.000Z"))
        let codexHome = try makeCodexHomeWithAuthAndLocalUsage()
        defer {
            try? FileManager.default.removeItem(at: codexHome)
        }
        let client = CodexUsageAPIClient(
            authStore: CodexAuthStore(codexHome: codexHome),
            cache: CodexUsageAPIRateLimitCache(url: nil),
            profileLoader: EmptyCodexUsageProfileLoader(),
            httpClient: StubHTTPClient(data: Data(#"{"error":"unavailable"}"#.utf8), statusCode: 500)
        )

        let snapshot = await client.loadSnapshot(codexHome: codexHome, now: now)

        XCTAssertNil(snapshot.rateLimits)
        XCTAssertNil(snapshot.latestEvent?.rateLimits)
        XCTAssertEqual(snapshot.tokensToday.totalTokens, 1_042_000)
        XCTAssertEqual(snapshot.eventCount, 1)

        let summary = CodexUsageSummary(snapshot: snapshot, now: now)
        XCTAssertEqual(summary.planText, "--")
        XCTAssertEqual(summary.fiveHourLimitText, "--")
        XCTAssertEqual(summary.sevenDayLimitText, "--")
        XCTAssertEqual(summary.todayTokensText, "1.0M")
    }

    private func makeCodexHomeWithAuthAndLocalUsage(
        eventLines: [String] = [
            """
            {"timestamp":"2026-05-25T04:10:00.000Z","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":1000000,"cached_input_tokens":700000,"output_tokens":42000,"total_tokens":1042000}},"rate_limits":{"primary":{"used_percent":2,"window_minutes":300},"secondary":{"used_percent":8,"window_minutes":10080},"plan_type":"stale"}}}
            """
        ]
    ) throws -> URL {
        let codexHome = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodexWatcherTests-hybrid-\(UUID().uuidString)")
        let sessions = codexHome.appendingPathComponent("sessions/2026/05/25")
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        try """
        {"tokens":{"access_token":"test-access-token","account_id":"test-account"}}
        """.write(
            to: codexHome.appendingPathComponent("auth.json"),
            atomically: true,
            encoding: .utf8
        )
        try eventLines.joined(separator: "\n").write(
            to: sessions.appendingPathComponent("rollout-local.jsonl"),
            atomically: true,
            encoding: .utf8
        )
        return codexHome
    }

    private func codexUsageAPIResponseData() -> Data {
        Data("""
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
    }
}

private struct StubUsageProfileLoader: CodexUsageProfileLoading {
    var profile: CodexUsageProfile?

    func loadUsageProfile(now _: Date) async -> CodexUsageProfile? {
        profile
    }
}

private struct StubHTTPClient: CodexUsageHTTPClient {
    var data: Data
    var statusCode: Int = 200

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (data, response)
    }
}

private struct StubHTTPResponse {
    var data: Data
    var statusCode: Int
}

private final class SequencedHTTPClient: CodexUsageHTTPClient, @unchecked Sendable {
    private var responses: [StubHTTPResponse]
    private(set) var requestedURLs: [URL] = []

    init(responses: [StubHTTPResponse]) {
        self.responses = responses
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requestedURLs.append(request.url!)
        let response = responses.isEmpty
            ? StubHTTPResponse(data: Data(), statusCode: 500)
            : responses.removeFirst()

        let httpResponse = HTTPURLResponse(
            url: request.url!,
            statusCode: response.statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (response.data, httpResponse)
    }
}
