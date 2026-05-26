import Foundation

public struct TokenUsage: Codable, Equatable, Sendable {
    public var inputTokens: Int
    public var cachedInputTokens: Int
    public var outputTokens: Int
    public var reasoningOutputTokens: Int
    public var totalTokens: Int

    public init(
        inputTokens: Int = 0,
        cachedInputTokens: Int = 0,
        outputTokens: Int = 0,
        reasoningOutputTokens: Int = 0,
        totalTokens: Int = 0
    ) {
        self.inputTokens = inputTokens
        self.cachedInputTokens = cachedInputTokens
        self.outputTokens = outputTokens
        self.reasoningOutputTokens = reasoningOutputTokens
        self.totalTokens = totalTokens
    }

    public var uncachedInputTokens: Int {
        max(inputTokens - cachedInputTokens, 0)
    }

    public static func + (lhs: TokenUsage, rhs: TokenUsage) -> TokenUsage {
        TokenUsage(
            inputTokens: lhs.inputTokens + rhs.inputTokens,
            cachedInputTokens: lhs.cachedInputTokens + rhs.cachedInputTokens,
            outputTokens: lhs.outputTokens + rhs.outputTokens,
            reasoningOutputTokens: lhs.reasoningOutputTokens + rhs.reasoningOutputTokens,
            totalTokens: lhs.totalTokens + rhs.totalTokens
        )
    }
}

public struct CodexDailyUsage: Codable, Equatable, Sendable {
    public var date: Date
    public var usage: TokenUsage

    public init(date: Date, usage: TokenUsage) {
        self.date = date
        self.usage = usage
    }
}

public struct RateWindow: Codable, Equatable, Sendable {
    public var usedPercent: Double
    public var windowMinutes: Int
    public var resetsAt: Date?

    public init(usedPercent: Double = 0, windowMinutes: Int = 0, resetsAt: Date? = nil) {
        self.usedPercent = usedPercent
        self.windowMinutes = windowMinutes
        self.resetsAt = resetsAt
    }
}

public struct RateLimits: Codable, Equatable, Sendable {
    public var primary: RateWindow?
    public var secondary: RateWindow?
    public var planType: String?

    public init(primary: RateWindow? = nil, secondary: RateWindow? = nil, planType: String? = nil) {
        self.primary = primary
        self.secondary = secondary
        self.planType = planType
    }
}

public struct CodexUsageEvent: Codable, Equatable, Sendable {
    public var timestamp: Date
    public var totalUsage: TokenUsage
    public var lastUsage: TokenUsage
    public var rateLimits: RateLimits?
    public var modelContextWindow: Int?

    public init(
        timestamp: Date,
        totalUsage: TokenUsage = TokenUsage(),
        lastUsage: TokenUsage = TokenUsage(),
        rateLimits: RateLimits? = nil,
        modelContextWindow: Int? = nil
    ) {
        self.timestamp = timestamp
        self.totalUsage = totalUsage
        self.lastUsage = lastUsage
        self.rateLimits = rateLimits
        self.modelContextWindow = modelContextWindow
    }
}

public struct CodexUsageSnapshot: Codable, Equatable, Sendable {
    public var latestEvent: CodexUsageEvent?
    public var rateLimits: RateLimits?
    public var tokensLast5Hours: TokenUsage
    public var tokensLast7Days: TokenUsage
    public var tokensToday: TokenUsage
    public var tokensThisWeek: TokenUsage
    public var dailyUsageLast7Days: [CodexDailyUsage]
    public var eventCount: Int

    public init(
        latestEvent: CodexUsageEvent? = nil,
        rateLimits: RateLimits? = nil,
        tokensLast5Hours: TokenUsage = TokenUsage(),
        tokensLast7Days: TokenUsage = TokenUsage(),
        tokensToday: TokenUsage = TokenUsage(),
        tokensThisWeek: TokenUsage = TokenUsage(),
        dailyUsageLast7Days: [CodexDailyUsage] = [],
        eventCount: Int = 0
    ) {
        self.latestEvent = latestEvent
        self.rateLimits = rateLimits
        self.tokensLast5Hours = tokensLast5Hours
        self.tokensLast7Days = tokensLast7Days
        self.tokensToday = tokensToday
        self.tokensThisWeek = tokensThisWeek
        self.dailyUsageLast7Days = dailyUsageLast7Days
        self.eventCount = eventCount
    }
}

public enum CodexUsageParser {
    public static func parseLine(_ line: String) -> CodexUsageEvent? {
        guard let data = line.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              root["type"] as? String == "event_msg",
              let payload = root["payload"] as? [String: Any],
              payload["type"] as? String == "token_count",
              let timestampText = root["timestamp"] as? String,
              let timestamp = parseDate(timestampText),
              let info = payload["info"] as? [String: Any] else {
            return nil
        }

        let totalUsage = tokenUsage(from: info["total_token_usage"] as? [String: Any])
        let lastUsage = tokenUsage(from: info["last_token_usage"] as? [String: Any])
        let modelContextWindow = info["model_context_window"] as? Int
        let rateLimits = rateLimits(from: payload["rate_limits"] as? [String: Any])

        return CodexUsageEvent(
            timestamp: timestamp,
            totalUsage: totalUsage,
            lastUsage: lastUsage,
            rateLimits: rateLimits,
            modelContextWindow: modelContextWindow
        )
    }

    public static func makeSnapshot(events: [CodexUsageEvent], now: Date, calendar: Calendar? = nil) -> CodexUsageSnapshot {
        let usageCalendar = calendar ?? defaultUsageCalendar()
        let latestEvent = events.max { lhs, rhs in
            lhs.timestamp < rhs.timestamp
        }
        let fiveHoursAgo = now.addingTimeInterval(-5 * 60 * 60)
        let sevenDaysAgo = now.addingTimeInterval(-7 * 24 * 60 * 60)
        let startOfToday = usageCalendar.startOfDay(for: now)
        let startOfWeek = usageCalendar.dateInterval(of: .weekOfYear, for: now)?.start ?? sevenDaysAgo

        return CodexUsageSnapshot(
            latestEvent: latestEvent,
            rateLimits: resolvedRateLimits(events: events, now: now, fallback: latestEvent?.rateLimits),
            tokensLast5Hours: sumLastUsage(events: events, since: fiveHoursAgo),
            tokensLast7Days: sumLastUsage(events: events, since: sevenDaysAgo),
            tokensToday: sumLastUsage(events: events, since: startOfToday),
            tokensThisWeek: sumLastUsage(events: events, since: startOfWeek),
            dailyUsageLast7Days: dailyUsageLast7Days(events: events, now: now, calendar: usageCalendar),
            eventCount: events.count
        )
    }

    private static func dailyUsageLast7Days(
        events: [CodexUsageEvent],
        now: Date,
        calendar: Calendar
    ) -> [CodexDailyUsage] {
        let today = calendar.startOfDay(for: now)
        guard let firstDay = calendar.date(byAdding: .day, value: -6, to: today) else {
            return []
        }

        var buckets: [Date: TokenUsage] = [:]
        for event in events {
            let day = calendar.startOfDay(for: event.timestamp)
            guard day >= firstDay, day <= today else {
                continue
            }
            buckets[day, default: TokenUsage()] = buckets[day, default: TokenUsage()] + event.lastUsage
        }

        return (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: firstDay) else {
                return nil
            }
            return CodexDailyUsage(date: day, usage: buckets[day, default: TokenUsage()])
        }
    }

    private static func resolvedRateLimits(events: [CodexUsageEvent], now: Date, fallback: RateLimits?) -> RateLimits? {
        let recentCutoff = now.addingTimeInterval(-10 * 60)
        let recentEvents = events.filter { event in
            event.timestamp >= recentCutoff && event.rateLimits != nil
        }
        guard !recentEvents.isEmpty else {
            return fallback
        }

        let latestPlanType = recentEvents.max { lhs, rhs in
            lhs.timestamp < rhs.timestamp
        }?.rateLimits?.planType ?? fallback?.planType

        return RateLimits(
            primary: conservativeWindow(recentEvents.compactMap { $0.rateLimits?.primary }) ?? fallback?.primary,
            secondary: conservativeWindow(recentEvents.compactMap { $0.rateLimits?.secondary }) ?? fallback?.secondary,
            planType: latestPlanType
        )
    }

    private static func conservativeWindow(_ windows: [RateWindow]) -> RateWindow? {
        windows.max { lhs, rhs in
            lhs.usedPercent < rhs.usedPercent
        }
    }

    private static func defaultUsageCalendar() -> Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }

    private static func tokenUsage(from dictionary: [String: Any]?) -> TokenUsage {
        guard let dictionary else {
            return TokenUsage()
        }

        return TokenUsage(
            inputTokens: intValue(dictionary["input_tokens"]),
            cachedInputTokens: intValue(dictionary["cached_input_tokens"]),
            outputTokens: intValue(dictionary["output_tokens"]),
            reasoningOutputTokens: intValue(dictionary["reasoning_output_tokens"]),
            totalTokens: intValue(dictionary["total_tokens"])
        )
    }

    private static func rateLimits(from dictionary: [String: Any]?) -> RateLimits? {
        guard let dictionary else {
            return nil
        }

        return RateLimits(
            primary: rateWindow(from: dictionary["primary"] as? [String: Any]),
            secondary: rateWindow(from: dictionary["secondary"] as? [String: Any]),
            planType: dictionary["plan_type"] as? String
        )
    }

    private static func rateWindow(from dictionary: [String: Any]?) -> RateWindow? {
        guard let dictionary else {
            return nil
        }

        let resetsAt: Date?
        if let timestamp = dictionary["resets_at"] {
            resetsAt = Date(timeIntervalSince1970: TimeInterval(intValue(timestamp)))
        } else {
            resetsAt = nil
        }

        return RateWindow(
            usedPercent: doubleValue(dictionary["used_percent"]),
            windowMinutes: intValue(dictionary["window_minutes"]),
            resetsAt: resetsAt
        )
    }

    private static func sumLastUsage(events: [CodexUsageEvent], since date: Date) -> TokenUsage {
        events.reduce(TokenUsage()) { partial, event in
            guard event.timestamp >= date else {
                return partial
            }
            return partial + event.lastUsage
        }
    }

    private static func parseDate(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) {
            return date
        }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: value)
    }

    private static func intValue(_ value: Any?) -> Int {
        if let value = value as? Int {
            return value
        }
        if let value = value as? Double {
            return Int(value)
        }
        if let value = value as? String, let intValue = Int(value) {
            return intValue
        }
        return 0
    }

    private static func doubleValue(_ value: Any?) -> Double {
        if let value = value as? Double {
            return value
        }
        if let value = value as? Int {
            return Double(value)
        }
        if let value = value as? String, let doubleValue = Double(value) {
            return doubleValue
        }
        return 0
    }
}
