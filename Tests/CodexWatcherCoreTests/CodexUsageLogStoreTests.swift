import XCTest
@testable import CodexWatcherCore

final class CodexUsageLogStoreTests: XCTestCase {
    func testLoadsSnapshotFromSessionsAndArchivedSessions() throws {
        let codexHome = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodexWatcherTests-\(UUID().uuidString)")
        defer {
            try? FileManager.default.removeItem(at: codexHome)
        }

        let sessions = codexHome.appendingPathComponent("sessions/2026/05/24")
        let archived = codexHome.appendingPathComponent("archived_sessions")
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: archived, withIntermediateDirectories: true)

        let recentLine = """
        {"timestamp":"2026-05-24T07:00:00.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":20,"cached_input_tokens":2,"output_tokens":4,"reasoning_output_tokens":1,"total_tokens":25},"last_token_usage":{"input_tokens":8,"cached_input_tokens":2,"output_tokens":1,"reasoning_output_tokens":1,"total_tokens":10}},"rate_limits":{"primary":{"used_percent":12,"window_minutes":300},"secondary":{"used_percent":21,"window_minutes":10080},"plan_type":"plus"}}}
        """
        let archivedLine = """
        {"timestamp":"2026-05-23T07:00:00.000Z","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":3,"cached_input_tokens":1,"output_tokens":1,"reasoning_output_tokens":0,"total_tokens":4}}}}
        """
        try [
            #"{"timestamp":"2026-05-24T06:00:00.000Z","type":"event_msg","payload":{"type":"note"}}"#,
            recentLine
        ].joined(separator: "\n").write(
            to: sessions.appendingPathComponent("rollout-current.jsonl"),
            atomically: true,
            encoding: .utf8
        )
        try archivedLine.write(
            to: archived.appendingPathComponent("rollout-archived.jsonl"),
            atomically: true,
            encoding: .utf8
        )

        let now = try XCTUnwrap(codexTestDate("2026-05-24T08:00:00.000Z"))
        let snapshot = CodexUsageLogStore.loadSnapshot(codexHome: codexHome, now: now)

        XCTAssertEqual(snapshot.eventCount, 2)
        XCTAssertEqual(snapshot.latestEvent?.totalUsage.totalTokens, 25)
        XCTAssertEqual(snapshot.latestEvent?.rateLimits?.primary?.usedPercent, 12)
        XCTAssertEqual(snapshot.tokensLast5Hours.totalTokens, 10)
        XCTAssertEqual(snapshot.tokensLast7Days.totalTokens, 14)
    }

    func testMissingCodexHomeReturnsEmptySnapshot() {
        let missingHome = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodexWatcherTests-missing-\(UUID().uuidString)")
        let snapshot = CodexUsageLogStore.loadSnapshot(codexHome: missingHome, now: Date())

        XCTAssertNil(snapshot.latestEvent)
        XCTAssertEqual(snapshot.eventCount, 0)
        XCTAssertEqual(snapshot.tokensLast5Hours.totalTokens, 0)
    }

    func testCacheReusesParsedEventsForUnchangedFiles() throws {
        let codexHome = try makeCodexHomeWithCurrentSession()
        defer {
            try? FileManager.default.removeItem(at: codexHome)
        }

        var readCount = 0
        let cache = CodexUsageLogCache(eventReader: { url, _ in
            readCount += 1
            return CodexUsageLogStore.readEvents(from: url)
        })
        let now = try XCTUnwrap(codexTestDate("2026-05-24T08:00:00.000Z"))
        let cutoff = now.addingTimeInterval(-8 * 24 * 60 * 60)

        XCTAssertEqual(cache.loadEvents(codexHome: codexHome, modifiedSince: cutoff).count, 1)
        XCTAssertEqual(cache.loadEvents(codexHome: codexHome, modifiedSince: cutoff).count, 1)
        XCTAssertEqual(readCount, 1)
    }

    func testCacheReadsOnlyAppendedBytesForGrowingFiles() throws {
        let codexHome = try makeCodexHomeWithCurrentSession()
        defer {
            try? FileManager.default.removeItem(at: codexHome)
        }

        let currentFile = codexHome.appendingPathComponent("sessions/2026/05/24/rollout-current.jsonl")
        let originalSize = try XCTUnwrap(currentFile.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        var offsets: [UInt64] = []
        let cache = CodexUsageLogCache(eventReader: { url, offset in
            offsets.append(offset)
            return CodexUsageLogStore.readEvents(from: url, startingAt: offset)
        })
        let now = try XCTUnwrap(codexTestDate("2026-05-24T08:00:00.000Z"))
        let cutoff = now.addingTimeInterval(-8 * 24 * 60 * 60)

        XCTAssertEqual(cache.loadEvents(codexHome: codexHome, modifiedSince: cutoff).count, 1)
        let appendedLine = """
        {"timestamp":"2026-05-24T07:30:00.000Z","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"total_tokens":7}}}}
        """
        let handle = try FileHandle(forWritingTo: currentFile)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("\n\(appendedLine)".utf8))
        try handle.close()

        XCTAssertEqual(cache.loadEvents(codexHome: codexHome, modifiedSince: cutoff).count, 2)
        XCTAssertEqual(offsets, [0, UInt64(originalSize)])
    }

    func testPersistentCacheAvoidsColdReparseForUnchangedFiles() throws {
        let codexHome = try makeCodexHomeWithCurrentSession()
        let cacheURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodexWatcherCache-\(UUID().uuidString)/usage-log-cache.json")
        defer {
            try? FileManager.default.removeItem(at: codexHome)
            try? FileManager.default.removeItem(at: cacheURL.deletingLastPathComponent())
        }

        var firstReadCount = 0
        let firstCache = CodexUsageLogCache(persistentCacheURL: cacheURL, eventReader: { url, offset in
            firstReadCount += 1
            return CodexUsageLogStore.readEvents(from: url, startingAt: offset)
        })
        let now = try XCTUnwrap(codexTestDate("2026-05-24T08:00:00.000Z"))
        let cutoff = now.addingTimeInterval(-8 * 24 * 60 * 60)

        XCTAssertEqual(firstCache.loadEvents(codexHome: codexHome, modifiedSince: cutoff).count, 1)
        XCTAssertEqual(firstReadCount, 1)

        var secondReadCount = 0
        let secondCache = CodexUsageLogCache(persistentCacheURL: cacheURL, eventReader: { _, _ in
            secondReadCount += 1
            return []
        })

        XCTAssertEqual(secondCache.loadEvents(codexHome: codexHome, modifiedSince: cutoff).count, 1)
        XCTAssertEqual(secondReadCount, 0)
    }

    func testWidgetTimelineRefreshIntervalIsOneMinute() {
        XCTAssertEqual(CodexWidgetRefreshPolicy.timelineRefreshInterval, 60)
    }

    private func makeCodexHomeWithCurrentSession() throws -> URL {
        let codexHome = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodexWatcherTests-\(UUID().uuidString)")
        let sessions = codexHome.appendingPathComponent("sessions/2026/05/24")
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)

        let line = """
        {"timestamp":"2026-05-24T07:00:00.000Z","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"total_tokens":10}}}}
        """
        try line.write(
            to: sessions.appendingPathComponent("rollout-current.jsonl"),
            atomically: true,
            encoding: .utf8
        )
        return codexHome
    }
}
