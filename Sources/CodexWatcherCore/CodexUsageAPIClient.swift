import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if os(macOS)
import Darwin
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

    public init(codexHome: URL = Self.defaultCodexHome()) {
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

    public static func defaultCodexHome() -> URL {
        realHomeDirectory().appendingPathComponent(".codex")
    }

    private static func realHomeDirectory() -> URL {
        #if os(macOS)
        if let passwd = getpwuid(getuid()),
           let home = passwd.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: home), isDirectory: true)
        }
        #endif

        return FileManager.default.homeDirectoryForCurrentUser
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
    public static let whamUsageURL = URL(string: "https://chatgpt.com/backend-api/wham/usage")!
    public static let codexUsageURL = URL(string: "https://chatgpt.com/backend-api/codex/usage")!
    public static let defaultUsageURL = whamUsageURL
    public static let defaultFallbackUsageURLs = [codexUsageURL]

    public var authStore: CodexAuthStore
    public var usageURL: URL
    public var fallbackUsageURLs: [URL]
    public var cache: CodexUsageAPIRateLimitCache

    private let profileLoader: any CodexUsageProfileLoading
    private let httpClient: any CodexUsageHTTPClient

    public init(
        authStore: CodexAuthStore = CodexAuthStore(),
        usageURL: URL = Self.defaultUsageURL,
        fallbackUsageURLs: [URL] = Self.defaultFallbackUsageURLs,
        cache: CodexUsageAPIRateLimitCache = CodexUsageAPIRateLimitCache(),
        profileLoader: any CodexUsageProfileLoading = CodexAppServerUsageClient(),
        httpClient: any CodexUsageHTTPClient = URLSession.shared
    ) {
        self.authStore = authStore
        self.usageURL = usageURL
        self.fallbackUsageURLs = fallbackUsageURLs
        self.cache = cache
        self.profileLoader = profileLoader
        self.httpClient = httpClient
    }

    public func fetchRateLimits() async throws -> RateLimits {
        var lastError: Error?
        for url in [usageURL] + fallbackUsageURLs {
            do {
                return try await fetchRateLimits(from: url)
            } catch {
                lastError = error
            }
        }

        throw lastError ?? CodexUsageAPIError.missingRateLimits
    }

    private func fetchRateLimits(from url: URL) async throws -> RateLimits {
        let auth = try authStore.loadChatGPTAuth()
        var request = URLRequest(url: url)
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

    public func loadSnapshot(now: Date = Date()) async -> CodexUsageSnapshot {
        await loadAPISnapshot(now: now)
    }

    public func loadSnapshot(codexHome: URL, now: Date = Date()) async -> CodexUsageSnapshot {
        var client = self
        client.authStore = CodexAuthStore(codexHome: codexHome)
        return await client.loadAPISnapshot(now: now)
    }

    private func loadAPISnapshot(now: Date) async -> CodexUsageSnapshot {
        let profile = await profileLoader.loadUsageProfile(now: now)
        do {
            let rateLimits = try await fetchRateLimits()
            cache.save(rateLimits: rateLimits, fetchedAt: now)
            return Self.apiSnapshot(rateLimits: rateLimits, now: now, profile: profile)
        } catch {
            if let cachedRateLimits = cache.load(now: now) {
                return Self.apiSnapshot(rateLimits: cachedRateLimits, now: now, profile: profile)
            }
            if let profile {
                return Self.profileSnapshot(profile: profile, now: now)
            }
            return CodexUsageSnapshot()
        }
    }

    public static func apply(
        apiRateLimits: RateLimits,
        to _: CodexUsageSnapshot,
        now: Date
    ) -> CodexUsageSnapshot {
        apiSnapshot(rateLimits: apiRateLimits, now: now, profile: nil)
    }

    private static func apiSnapshot(rateLimits: RateLimits, now: Date, profile: CodexUsageProfile?) -> CodexUsageSnapshot {
        return CodexUsageSnapshot(
            latestEvent: CodexUsageEvent(timestamp: now, rateLimits: rateLimits),
            rateLimits: rateLimits,
            tokensToday: profile?.tokensToday ?? TokenUsage(),
            tokensThisWeek: profile?.tokensThisWeek ?? TokenUsage(),
            dailyUsageLast7Days: profile?.dailyUsageLast7Days ?? []
        )
    }

    private static func profileSnapshot(profile: CodexUsageProfile, now: Date) -> CodexUsageSnapshot {
        return CodexUsageSnapshot(
            latestEvent: CodexUsageEvent(timestamp: now),
            tokensToday: profile.tokensToday,
            tokensThisWeek: profile.tokensThisWeek,
            dailyUsageLast7Days: profile.dailyUsageLast7Days
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
