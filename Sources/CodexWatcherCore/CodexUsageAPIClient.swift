import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum CodexUsageAPIError: Error, Equatable {
    case missingAuth
    case invalidHTTPResponse
    case requestFailed(statusCode: Int)
    case missingRateLimits
}

public struct CodexChatGPTAuth: Equatable, Sendable {
    public var accessToken: String
    public var accountID: String

    public init(accessToken: String, accountID: String) {
        self.accessToken = accessToken
        self.accountID = accountID
    }
}

public struct CodexAuthStore: Sendable {
    public var codexHome: URL

    public init(codexHome: URL = CodexUsageLogStore.defaultCodexHome()) {
        self.codexHome = codexHome
    }

    public func loadChatGPTAuth() throws -> CodexChatGPTAuth {
        let authURL = codexHome.appendingPathComponent("auth.json")
        let data = try Data(contentsOf: authURL)
        let authFile = try JSONDecoder().decode(CodexAuthFile.self, from: data)
        guard let accessToken = authFile.tokens?.accessToken,
              let accountID = authFile.tokens?.accountID,
              !accessToken.isEmpty,
              !accountID.isEmpty else {
            throw CodexUsageAPIError.missingAuth
        }

        return CodexChatGPTAuth(accessToken: accessToken, accountID: accountID)
    }
}

public protocol CodexUsageHTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: CodexUsageHTTPClient {}

public struct CodexUsageAPIRateLimitCache: Sendable {
    public var url: URL?
    public var maxAge: TimeInterval

    public init(url: URL? = Self.defaultURL(), maxAge: TimeInterval = 10 * 60) {
        self.url = url
        self.maxAge = maxAge
    }

    public func load(now: Date) -> RateLimits? {
        guard let url,
              let data = try? Data(contentsOf: url),
              let cached = try? JSONDecoder().decode(CachedRateLimits.self, from: data),
              now.timeIntervalSince(cached.fetchedAt) <= maxAge else {
            return nil
        }
        return cached.rateLimits
    }

    public func save(rateLimits: RateLimits, fetchedAt: Date) {
        guard let url else {
            return
        }

        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(CachedRateLimits(rateLimits: rateLimits, fetchedAt: fetchedAt))
            try data.write(to: url, options: .atomic)
        } catch {
            return
        }
    }

    public static func defaultURL() -> URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("QuotaScope", isDirectory: true)
            .appendingPathComponent("usage-api-cache.json")
    }

    private struct CachedRateLimits: Codable {
        var rateLimits: RateLimits
        var fetchedAt: Date
    }
}

public struct CodexUsageAPIClient: Sendable {
    public static let defaultUsageURL = URL(string: "https://chatgpt.com/backend-api/codex/usage")!

    public var authStore: CodexAuthStore
    public var usageURL: URL
    public var cache: CodexUsageAPIRateLimitCache

    private let httpClient: any CodexUsageHTTPClient

    public init(
        authStore: CodexAuthStore = CodexAuthStore(),
        usageURL: URL = Self.defaultUsageURL,
        cache: CodexUsageAPIRateLimitCache = CodexUsageAPIRateLimitCache(),
        httpClient: any CodexUsageHTTPClient = URLSession.shared
    ) {
        self.authStore = authStore
        self.usageURL = usageURL
        self.cache = cache
        self.httpClient = httpClient
    }

    public func fetchRateLimits() async throws -> RateLimits {
        let auth = try authStore.loadChatGPTAuth()
        var request = URLRequest(url: usageURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(auth.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(auth.accountID, forHTTPHeaderField: "ChatGPT-Account-Id")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("QuotaScope", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await httpClient.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CodexUsageAPIError.invalidHTTPResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw CodexUsageAPIError.requestFailed(statusCode: httpResponse.statusCode)
        }

        return try CodexUsageAPIResponse.decodeRateLimits(from: data)
    }

    public func loadSnapshot(
        codexHome: URL = CodexUsageLogStore.defaultCodexHome(),
        now: Date = Date()
    ) async -> CodexUsageSnapshot {
        let localSnapshot = CodexUsageLogStore.loadSnapshot(codexHome: codexHome, now: now)
        return await loadSnapshot(localSnapshot: localSnapshot, now: now)
    }

    public func loadSnapshot(localSnapshot: CodexUsageSnapshot, now: Date = Date()) async -> CodexUsageSnapshot {
        do {
            let rateLimits = try await fetchRateLimits()
            cache.save(rateLimits: rateLimits, fetchedAt: now)
            return Self.apply(apiRateLimits: rateLimits, to: localSnapshot, now: now)
        } catch {
            if let cachedRateLimits = cache.load(now: now) {
                return Self.apply(apiRateLimits: cachedRateLimits, to: localSnapshot, now: now)
            }
            return Self.removingLocalRateLimits(from: localSnapshot)
        }
    }

    public static func apply(
        apiRateLimits: RateLimits,
        to snapshot: CodexUsageSnapshot,
        now: Date
    ) -> CodexUsageSnapshot {
        let latestEvent: CodexUsageEvent
        if var existing = snapshot.latestEvent {
            existing.timestamp = now
            existing.rateLimits = apiRateLimits
            latestEvent = existing
        } else {
            latestEvent = CodexUsageEvent(timestamp: now, rateLimits: apiRateLimits)
        }

        return CodexUsageSnapshot(
            latestEvent: latestEvent,
            rateLimits: apiRateLimits,
            tokensLast5Hours: snapshot.tokensLast5Hours,
            tokensLast7Days: snapshot.tokensLast7Days,
            tokensToday: snapshot.tokensToday,
            tokensThisWeek: snapshot.tokensThisWeek,
            dailyUsageLast7Days: snapshot.dailyUsageLast7Days,
            eventCount: snapshot.eventCount
        )
    }

    public static func removingLocalRateLimits(from snapshot: CodexUsageSnapshot) -> CodexUsageSnapshot {
        var latestEvent = snapshot.latestEvent
        latestEvent?.rateLimits = nil

        return CodexUsageSnapshot(
            latestEvent: latestEvent,
            rateLimits: nil,
            tokensLast5Hours: snapshot.tokensLast5Hours,
            tokensLast7Days: snapshot.tokensLast7Days,
            tokensToday: snapshot.tokensToday,
            tokensThisWeek: snapshot.tokensThisWeek,
            dailyUsageLast7Days: snapshot.dailyUsageLast7Days,
            eventCount: snapshot.eventCount
        )
    }
}

public enum CodexUsageAPIResponse {
    public static func decodeRateLimits(from data: Data) throws -> RateLimits {
        let response = try JSONDecoder().decode(Response.self, from: data)
        guard let rateLimit = response.rateLimit else {
            throw CodexUsageAPIError.missingRateLimits
        }

        return RateLimits(
            primary: rateWindow(from: rateLimit.primaryWindow),
            secondary: rateWindow(from: rateLimit.secondaryWindow),
            planType: response.planType
        )
    }

    private static func rateWindow(from window: Window?) -> RateWindow? {
        guard let window else {
            return nil
        }

        return RateWindow(
            usedPercent: window.usedPercent,
            windowMinutes: window.limitWindowSeconds / 60,
            resetsAt: Date(timeIntervalSince1970: TimeInterval(window.resetAt))
        )
    }

    private struct Response: Decodable {
        var planType: String?
        var rateLimit: RateLimit?

        enum CodingKeys: String, CodingKey {
            case planType = "plan_type"
            case rateLimit = "rate_limit"
        }
    }

    private struct RateLimit: Decodable {
        var primaryWindow: Window?
        var secondaryWindow: Window?

        enum CodingKeys: String, CodingKey {
            case primaryWindow = "primary_window"
            case secondaryWindow = "secondary_window"
        }
    }

    private struct Window: Decodable {
        var usedPercent: Double
        var limitWindowSeconds: Int
        var resetAt: Int

        enum CodingKeys: String, CodingKey {
            case usedPercent = "used_percent"
            case limitWindowSeconds = "limit_window_seconds"
            case resetAt = "reset_at"
        }
    }
}

private struct CodexAuthFile: Decodable {
    var tokens: Tokens?

    struct Tokens: Decodable {
        var accessToken: String?
        var accountID: String?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case accountID = "account_id"
        }
    }
}
