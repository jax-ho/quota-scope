import Foundation

public struct CodexUsageProfile: Codable, Equatable, Sendable {
    public var tokensToday: TokenUsage
    public var tokensThisWeek: TokenUsage
    public var dailyUsageLast7Days: [CodexDailyUsage]

    public init(
        tokensToday: TokenUsage = TokenUsage(),
        tokensThisWeek: TokenUsage = TokenUsage(),
        dailyUsageLast7Days: [CodexDailyUsage] = []
    ) {
        self.tokensToday = tokensToday
        self.tokensThisWeek = tokensThisWeek
        self.dailyUsageLast7Days = dailyUsageLast7Days
    }
}

public protocol CodexUsageProfileLoading: Sendable {
    func loadUsageProfile(now: Date) async -> CodexUsageProfile?
}

public struct EmptyCodexUsageProfileLoader: CodexUsageProfileLoading {
    public init() {}

    public func loadUsageProfile(now _: Date) async -> CodexUsageProfile? {
        nil
    }
}

public struct CodexUsageProfileCache: Sendable {
    public var url: URL?
    public var maxAge: TimeInterval

    public init(url: URL? = Self.defaultURL(), maxAge: TimeInterval = 10 * 60) {
        self.url = url
        self.maxAge = maxAge
    }

    public func load(now: Date) -> CodexUsageProfile? {
        guard let url,
              let data = try? Data(contentsOf: url),
              let cached = try? JSONDecoder().decode(CachedUsageProfile.self, from: data),
              now.timeIntervalSince(cached.fetchedAt) <= maxAge else {
            return nil
        }
        return cached.profile
    }

    public func save(profile: CodexUsageProfile, fetchedAt: Date) {
        guard let url else {
            return
        }

        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(CachedUsageProfile(profile: profile, fetchedAt: fetchedAt))
            try data.write(to: url, options: .atomic)
        } catch {
            return
        }
    }

    public static func defaultURL(codexHome: URL = CodexAuthStore.defaultCodexHome()) -> URL? {
        codexHome
            .appendingPathComponent("QuotaScope", isDirectory: true)
            .appendingPathComponent("usage-profile-cache.json")
    }

    private struct CachedUsageProfile: Codable {
        var profile: CodexUsageProfile
        var fetchedAt: Date
    }
}

public struct CodexAppServerUsageClient: CodexUsageProfileLoading {
    public var executableURL: URL?
    public var cache: CodexUsageProfileCache
    public var timeout: TimeInterval

    public init(
        executableURL: URL? = nil,
        cache: CodexUsageProfileCache = CodexUsageProfileCache(),
        timeout: TimeInterval = 8
    ) {
        self.executableURL = executableURL
        self.cache = cache
        self.timeout = timeout
    }

    public func loadUsageProfile(now: Date = Date()) async -> CodexUsageProfile? {
        if let cached = cache.load(now: now) {
            return cached
        }

        guard let executableURL = executableURL ?? Self.defaultExecutableURL(),
              let data = await Self.runUsageRead(executableURL: executableURL, timeout: timeout) else {
            return nil
        }

        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .autoupdatingCurrent

        guard let profile = try? CodexAppServerUsageResponse.decodeProfile(
            from: data,
            now: now,
            calendar: calendar
        ) else {
            return nil
        }

        cache.save(profile: profile, fetchedAt: now)
        return profile
    }

    public static func defaultExecutableURL() -> URL? {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser.path
        let pathCandidates = [
            "/Applications/Codex.app/Contents/Resources/codex",
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            "\(home)/.nvm/versions/node/v24.16.0/bin/codex"
        ]

        for path in pathCandidates where fileManager.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }

        let pathEnvironment = ProcessInfo.processInfo.environment["PATH"] ?? ""
        for directory in pathEnvironment.split(separator: ":") {
            let path = URL(fileURLWithPath: String(directory)).appendingPathComponent("codex").path
            if fileManager.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }

        return nil
    }

    private static func runUsageRead(executableURL: URL, timeout: TimeInterval) async -> Data? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                continuation.resume(returning: runUsageReadSynchronously(executableURL: executableURL, timeout: timeout))
            }
        }
    }

    private static func runUsageReadSynchronously(executableURL: URL, timeout: TimeInterval) -> Data? {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = ["app-server"]

        let input = Pipe()
        let output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return nil
        }

        let accumulator = UsageReadAccumulator()
        let semaphore = DispatchSemaphore(value: 0)
        output.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                return
            }
            if accumulator.append(data) != nil {
                semaphore.signal()
            }
        }

        let initializeLine = #"{"method":"initialize","id":1,"params":{"clientInfo":{"name":"quotascope","title":"QuotaScope","version":"1"},"capabilities":{"experimentalApi":true}}}"#
        input.fileHandleForWriting.write(Data((initializeLine + "\n").utf8))
        guard accumulator.waitForInitialize(timeout: timeout) else {
            input.fileHandleForWriting.closeFile()
            output.fileHandleForReading.readabilityHandler = nil
            if process.isRunning {
                process.terminate()
            }
            return nil
        }

        let usageLines = [
            #"{"method":"initialized","params":{}}"#,
            #"{"method":"account/usage/read","id":2,"params":{}}"#
        ]
        input.fileHandleForWriting.write(Data((usageLines.joined(separator: "\n") + "\n").utf8))

        _ = semaphore.wait(timeout: .now() + timeout)
        input.fileHandleForWriting.closeFile()
        output.fileHandleForReading.readabilityHandler = nil

        if process.isRunning {
            process.terminate()
            Thread.sleep(forTimeInterval: 0.1)
            if process.isRunning {
                process.interrupt()
            }
        }

        return accumulator.result
    }

    static func usageResultData(fromJSONLine data: Data) -> Data? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["id"] as? Int == 2,
              let result = object["result"] else {
            return nil
        }

        return try? JSONSerialization.data(withJSONObject: result)
    }
}

private final class UsageReadAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private let initializeSemaphore = DispatchSemaphore(value: 0)
    private var buffer = Data()
    private var sawInitialize = false
    private(set) var result: Data?

    func waitForInitialize(timeout: TimeInterval) -> Bool {
        if initialized {
            return true
        }
        return initializeSemaphore.wait(timeout: .now() + timeout) == .success
    }

    func append(_ data: Data) -> Data? {
        lock.lock()
        defer {
            lock.unlock()
        }

        buffer.append(data)
        let newline = Data([0x0A])
        while let range = buffer.firstRange(of: newline) {
            let line = buffer[..<range.lowerBound]
            buffer.removeSubrange(buffer.startIndex..<range.upperBound)
            if sawInitializeResponse(Data(line)) {
                sawInitialize = true
                initializeSemaphore.signal()
            }
            guard result == nil,
                  let resultData = CodexAppServerUsageClient.usageResultData(fromJSONLine: Data(line)) else {
                continue
            }
            result = resultData
            return resultData
        }

        return result
    }

    private var initialized: Bool {
        lock.lock()
        defer {
            lock.unlock()
        }
        return sawInitialize
    }

    private func sawInitializeResponse(_ data: Data) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["id"] as? Int == 1,
              object["result"] != nil else {
            return false
        }
        return true
    }
}

public enum CodexAppServerUsageResponse {
    public static func decodeProfile(from data: Data, now: Date, calendar: Calendar) throws -> CodexUsageProfile {
        let response = try JSONDecoder().decode(Response.self, from: data)
        guard !response.dailyUsageBuckets.isEmpty else {
            return CodexUsageProfile()
        }

        let buckets = try bucketMap(from: response.dailyUsageBuckets, calendar: calendar)
        let today = calendar.startOfDay(for: now)
        let firstDay = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? firstDay

        let todayTokens = buckets[today, default: 0]
        let weekTokens = buckets.reduce(0) { partial, item in
            let (date, tokens) = item
            guard date >= startOfWeek && date <= today else {
                return partial
            }
            return partial + tokens
        }

        let dailyUsage: [CodexDailyUsage] = (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: firstDay) else {
                return nil
            }
            return CodexDailyUsage(date: day, usage: TokenUsage(totalTokens: buckets[day, default: 0]))
        }

        return CodexUsageProfile(
            tokensToday: TokenUsage(totalTokens: todayTokens),
            tokensThisWeek: TokenUsage(totalTokens: weekTokens),
            dailyUsageLast7Days: dailyUsage
        )
    }

    private static func bucketMap(from buckets: [DailyUsageBucket], calendar: Calendar) throws -> [Date: Int] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"

        var result: [Date: Int] = [:]
        for bucket in buckets {
            guard let date = formatter.date(from: bucket.startDate) else {
                continue
            }
            result[calendar.startOfDay(for: date), default: 0] += bucket.tokens
        }
        return result
    }

    private struct Response: Decodable {
        var dailyUsageBuckets: [DailyUsageBucket]
        var summary: Summary?
    }

    private struct DailyUsageBucket: Decodable {
        var startDate: String
        var tokens: Int
    }

    private struct Summary: Decodable {
        var lifetimeTokens: Int?
        var peakDailyTokens: Int?
        var longestRunningTurnSec: Int?
        var currentStreakDays: Int?
        var longestStreakDays: Int?
    }
}
