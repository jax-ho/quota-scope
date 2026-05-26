import Foundation

public struct CodexWidgetWeeklyBar: Equatable, Sendable {
    public let label: String
    public let valueText: String
    public let normalizedHeight: Double
    public let isToday: Bool
}

public struct CodexUsageSummary: Equatable, Sendable {
    public let title: String
    public let planText: String
    public let planBadgeText: String
    public let fiveHourLimitLabelText: String
    public let sevenDayLimitLabelText: String
    public let fiveHourResetText: String
    public let sevenDayResetText: String
    public let fiveHourLimitText: String
    public let sevenDayLimitText: String
    public let fiveHourLimitPercent: Double?
    public let sevenDayLimitPercent: Double?
    public let todayTokensText: String
    public let todayInputMissText: String
    public let todayInputCacheText: String
    public let todayOutputText: String
    public let thisWeekTokensText: String
    public let thisWeekInputMissText: String
    public let thisWeekInputCacheText: String
    public let thisWeekOutputText: String
    public let weekSummaryText: String
    public let updatedAtText: String
    public let weeklyBars: [CodexWidgetWeeklyBar]
    public let isEmpty: Bool

    public init(snapshot: CodexUsageSnapshot, now: Date = Date(), timeZone: TimeZone = .autoupdatingCurrent) {
        title = "QuotaScope"

        guard let latest = snapshot.latestEvent else {
            planText = "--"
            planBadgeText = "--"
            fiveHourLimitLabelText = "5h remaining"
            sevenDayLimitLabelText = "7d remaining"
            fiveHourResetText = "--"
            sevenDayResetText = "--"
            fiveHourLimitText = "--"
            sevenDayLimitText = "--"
            fiveHourLimitPercent = nil
            sevenDayLimitPercent = nil
            todayTokensText = "--"
            todayInputMissText = "--"
            todayInputCacheText = "--"
            todayOutputText = "--"
            thisWeekTokensText = "--"
            thisWeekInputMissText = "--"
            thisWeekInputCacheText = "--"
            thisWeekOutputText = "--"
            weekSummaryText = "Week --"
            updatedAtText = "Waiting for Codex usage"
            weeklyBars = []
            isEmpty = true
            return
        }

        let rateLimits = snapshot.rateLimits ?? latest.rateLimits
        let primaryPercent = Self.remainingPercent(fromUsedPercent: rateLimits?.primary?.usedPercent)
        let secondaryPercent = Self.remainingPercent(fromUsedPercent: rateLimits?.secondary?.usedPercent)

        planText = rateLimits?.planType ?? "--"
        planBadgeText = planText
        fiveHourLimitLabelText = "5h remaining"
        sevenDayLimitLabelText = "7d remaining"
        fiveHourResetText = Self.resetText(rateLimits?.primary?.resetsAt, now: now, timeZone: timeZone)
        sevenDayResetText = Self.resetText(rateLimits?.secondary?.resetsAt, now: now, timeZone: timeZone)
        fiveHourLimitText = Self.percentText(primaryPercent)
        sevenDayLimitText = Self.percentText(secondaryPercent)
        fiveHourLimitPercent = primaryPercent
        sevenDayLimitPercent = secondaryPercent
        todayTokensText = Self.shortNumber(snapshot.tokensToday.totalTokens)
        todayInputMissText = Self.shortNumber(snapshot.tokensToday.uncachedInputTokens)
        todayInputCacheText = Self.shortNumber(snapshot.tokensToday.cachedInputTokens)
        todayOutputText = Self.shortNumber(snapshot.tokensToday.outputTokens)
        thisWeekTokensText = Self.shortNumber(snapshot.tokensThisWeek.totalTokens)
        thisWeekInputMissText = Self.shortNumber(snapshot.tokensThisWeek.uncachedInputTokens)
        thisWeekInputCacheText = Self.shortNumber(snapshot.tokensThisWeek.cachedInputTokens)
        thisWeekOutputText = Self.shortNumber(snapshot.tokensThisWeek.outputTokens)
        weekSummaryText = "Week \(thisWeekTokensText)"
        updatedAtText = Self.timeText(latest.timestamp, timeZone: timeZone)
        weeklyBars = Self.weeklyBars(snapshot.dailyUsageLast7Days, now: now, timeZone: timeZone)
        isEmpty = false
    }

    private static func percentText(_ value: Double?) -> String {
        guard let value else {
            return "--"
        }
        return "\(Int(value.rounded()))%"
    }

    private static func remainingPercent(fromUsedPercent value: Double?) -> Double? {
        guard let value else {
            return nil
        }
        return min(max(100 - value, 0), 100)
    }

    private static func resetText(_ resetAt: Date?, now: Date, timeZone: TimeZone) -> String {
        guard let resetAt else {
            return "--"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        formatter.dateFormat = calendar.isDate(resetAt, inSameDayAs: now) ? "HH:mm" : "MM/dd HH:mm"

        return "until \(formatter.string(from: resetAt))"
    }

    private static func shortNumber(_ value: Int) -> String {
        let number = Double(value)
        if number >= 1_000_000 {
            return String(format: "%.1fM", number / 1_000_000)
        }
        if number >= 1_000 {
            return String(format: "%.1fK", number / 1_000)
        }
        return "\(value)"
    }

    private static func shortWholeNumber(_ value: Int) -> String {
        let number = Double(value)
        if number >= 1_000_000 {
            return "\(Int((number / 1_000_000).rounded()))M"
        }
        if number >= 1_000 {
            return "\(Int((number / 1_000).rounded()))K"
        }
        return "\(value)"
    }

    private static func timeText(_ value: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm"
        return "Updated \(formatter.string(from: value))"
    }

    private static func weeklyBars(_ dailyUsage: [CodexDailyUsage], now: Date, timeZone: TimeZone) -> [CodexWidgetWeeklyBar] {
        guard !dailyUsage.isEmpty else {
            return []
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let maxTokens = dailyUsage.map(\.usage.totalTokens).max() ?? 0

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "EEE"

        return dailyUsage.map { day in
            let isToday = calendar.isDate(day.date, inSameDayAs: now)
            let normalizedHeight = maxTokens > 0 ? Double(day.usage.totalTokens) / Double(maxTokens) : 0
            return CodexWidgetWeeklyBar(
                label: isToday ? "Today" : formatter.string(from: day.date),
                valueText: Self.shortWholeNumber(day.usage.totalTokens),
                normalizedHeight: min(max(normalizedHeight, 0), 1),
                isToday: isToday
            )
        }
    }
}

public enum CodexWidgetLayoutMetrics {
    public static let smallSystemHeight = 170.0
    public static let smallVerticalPadding = 10.0
    public static let smallSectionSpacing = 6.0
    public static let smallHeaderHeight = 18.0
    public static let smallLimitRowsHeight = 46.0
    public static let smallTokenHeaderHeight = 22.0
    public static let smallTokenDetailsHeight = 39.0

    public static let mediumSystemHeight = 164.0
    public static let mediumVerticalPadding = 10.0
    public static let mediumSectionSpacing = 7.0
    public static let mediumHeaderHeight = 18.0
    public static let mediumLimitBlockHeight = 38.0
    public static let mediumTokenBlockHeight = 64.0

    public static let largeSystemHeight = 360.0
    public static let largeVerticalPadding = 14.0
    public static let largeHeaderHeight = 26.0
    public static let largeSectionTitleHeight = 12.0
    public static let largeSectionSpacing = 12.0
    public static let largeQuotaCardsHeight = 45.0
    public static let largeChartHeight = 174.0

    public static var smallEstimatedContentHeight: Double {
        smallVerticalPadding * 2
            + smallHeaderHeight
            + smallSectionSpacing * 4
            + smallLimitRowsHeight
            + smallTokenHeaderHeight
            + smallTokenDetailsHeight
    }

    public static var mediumEstimatedContentHeight: Double {
        mediumVerticalPadding * 2
            + mediumHeaderHeight
            + mediumSectionSpacing * 2
            + mediumLimitBlockHeight
            + mediumTokenBlockHeight
    }

    public static var largeEstimatedContentHeight: Double {
        largeVerticalPadding
            + largeHeaderHeight
            + 14.0
            + largeSectionTitleHeight
            + 5.0
            + largeQuotaCardsHeight
            + 12.0
            + largeSectionTitleHeight
            + 7.0
            + largeChartHeight
    }
}
