import XCTest
@testable import CodexWatcherCore

final class CodexUsageProfileTests: XCTestCase {
    func testDecodesAppServerUsageBucketsIntoLastSevenDaysProfile() throws {
        let data = Data("""
        {
          "dailyUsageBuckets": [
            {"startDate": "2026-06-08", "tokens": 27974994},
            {"startDate": "2026-06-09", "tokens": 126395029},
            {"startDate": "2026-06-10", "tokens": 6588974},
            {"startDate": "2026-06-11", "tokens": 35779928},
            {"startDate": "2026-06-12", "tokens": 49044300},
            {"startDate": "2026-06-13", "tokens": 15678028}
          ],
          "summary": {
            "lifetimeTokens": 3180855437,
            "peakDailyTokens": 173890959,
            "longestRunningTurnSec": 7964,
            "currentStreakDays": 7,
            "longestStreakDays": 16
          }
        }
        """.utf8)
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 8 * 60 * 60))
        let now = try XCTUnwrap(codexTestDate("2026-06-14T08:00:00.000Z"))

        let profile = try CodexAppServerUsageResponse.decodeProfile(
            from: data,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(profile.tokensToday.totalTokens, 0)
        XCTAssertEqual(profile.tokensThisWeek.totalTokens, 261_461_253)
        XCTAssertEqual(profile.dailyUsageLast7Days.map(\.usage.totalTokens), [
            27_974_994,
            126_395_029,
            6_588_974,
            35_779_928,
            49_044_300,
            15_678_028,
            0
        ])
    }
}
