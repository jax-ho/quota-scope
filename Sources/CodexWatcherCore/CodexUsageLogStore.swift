import Foundation
#if os(macOS)
import Darwin
#endif

public enum CodexWidgetRefreshPolicy {
    public static let timelineRefreshInterval: TimeInterval = 60
}

public enum CodexUsageLogStore {
    private static let sharedCache = CodexUsageLogCache(persistentCacheURL: defaultCacheURL())

    public static func defaultCodexHome() -> URL {
        realHomeDirectory().appendingPathComponent(".codex")
    }

    public static func loadSnapshot(codexHome: URL = defaultCodexHome(), now: Date = Date()) -> CodexUsageSnapshot {
        let cutoff = now.addingTimeInterval(-8 * 24 * 60 * 60)
        return CodexUsageParser.makeSnapshot(events: loadEvents(codexHome: codexHome, modifiedSince: cutoff), now: now)
    }

    public static func loadEvents(codexHome: URL = defaultCodexHome(), modifiedSince: Date = .distantPast) -> [CodexUsageEvent] {
        sharedCache.loadEvents(codexHome: codexHome, modifiedSince: modifiedSince)
    }

    static func jsonlFiles(under root: URL, modifiedSince: Date) -> [CodexUsageFileRecord] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return enumerator.compactMap { item in
            guard let url = item as? URL, url.pathExtension == "jsonl" else {
                return nil
            }
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey])
            guard values?.isRegularFile == true,
                  let modificationDate = values?.contentModificationDate,
                  modificationDate >= modifiedSince else {
                return nil
            }
            return CodexUsageFileRecord(
                url: url,
                modificationDate: modificationDate,
                fileSize: Int64(values?.fileSize ?? 0)
            )
        }
    }

    static func readEvents(from file: URL, startingAt offset: UInt64 = 0) -> [CodexUsageEvent] {
        guard let handle = try? FileHandle(forReadingFrom: file) else {
            return []
        }
        defer {
            try? handle.close()
        }
        if offset > 0 {
            try? handle.seek(toOffset: offset)
        }

        let newline = UInt8(ascii: "\n")
        let tokenPattern = Data(#""token_count""#.utf8)
        let maxUsefulPrefixBytes = 4_096
        var events: [CodexUsageEvent] = []
        var lineBuffer = Data()
        var discardingLine = false

        while true {
            let chunk = (try? handle.read(upToCount: 64 * 1024)) ?? Data()
            guard !chunk.isEmpty else {
                break
            }

            var segmentStart = chunk.startIndex
            var cursor = chunk.startIndex
            while cursor < chunk.endIndex {
                if chunk[cursor] == newline {
                    appendLineSegment(
                        chunk[segmentStart..<cursor],
                        to: &lineBuffer,
                        discardingLine: &discardingLine,
                        tokenPattern: tokenPattern,
                        maxUsefulPrefixBytes: maxUsefulPrefixBytes
                    )
                    appendEventIfNeeded(from: lineBuffer, tokenPattern: tokenPattern, events: &events)
                    lineBuffer.removeAll(keepingCapacity: true)
                    discardingLine = false
                    segmentStart = chunk.index(after: cursor)
                }
                cursor = chunk.index(after: cursor)
            }

            appendLineSegment(
                chunk[segmentStart..<chunk.endIndex],
                to: &lineBuffer,
                discardingLine: &discardingLine,
                tokenPattern: tokenPattern,
                maxUsefulPrefixBytes: maxUsefulPrefixBytes
            )
        }

        appendEventIfNeeded(from: lineBuffer, tokenPattern: tokenPattern, events: &events)
        return events
    }

    static func rootDirectories(codexHome: URL) -> [URL] {
        [
            codexHome.appendingPathComponent("sessions"),
            codexHome.appendingPathComponent("archived_sessions")
        ]
    }

    static func defaultCacheURL() -> URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("CodexWatcher", isDirectory: true)
            .appendingPathComponent("usage-log-cache.json")
    }

    private static func appendLineSegment(
        _ segment: Data.SubSequence,
        to lineBuffer: inout Data,
        discardingLine: inout Bool,
        tokenPattern: Data,
        maxUsefulPrefixBytes: Int
    ) {
        guard !discardingLine else {
            return
        }

        lineBuffer.append(segment)
        if lineBuffer.count > maxUsefulPrefixBytes,
           lineBuffer.range(of: tokenPattern) == nil {
            lineBuffer.removeAll(keepingCapacity: true)
            discardingLine = true
        }
    }

    private static func appendEventIfNeeded(
        from lineBuffer: Data,
        tokenPattern: Data,
        events: inout [CodexUsageEvent]
    ) {
        guard lineBuffer.range(of: tokenPattern) != nil,
              let line = String(data: lineBuffer, encoding: .utf8),
              let event = CodexUsageParser.parseLine(line) else {
            return
        }
        events.append(event)
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

struct CodexUsageFileRecord {
    let url: URL
    let modificationDate: Date
    let fileSize: Int64
}

final class CodexUsageLogCache: @unchecked Sendable {
    private struct CachedFile {
        let fingerprint: FileFingerprint
        let events: [CodexUsageEvent]
    }

    private struct FileFingerprint: Equatable {
        let modificationDate: Date
        let fileSize: Int64

        static func == (lhs: FileFingerprint, rhs: FileFingerprint) -> Bool {
            lhs.fileSize == rhs.fileSize
                && abs(lhs.modificationDate.timeIntervalSince(rhs.modificationDate)) < 0.001
        }
    }

    private let eventReader: (URL, UInt64) -> [CodexUsageEvent]
    private let persistentCacheURL: URL?
    private let lock = NSLock()
    private var cachedFiles: [String: CachedFile] = [:]
    private var didLoadPersistentCache = false

    init(
        persistentCacheURL: URL? = nil,
        eventReader: @escaping (URL, UInt64) -> [CodexUsageEvent] = CodexUsageLogStore.readEvents
    ) {
        self.persistentCacheURL = persistentCacheURL
        self.eventReader = eventReader
    }

    func loadEvents(codexHome: URL, modifiedSince: Date) -> [CodexUsageEvent] {
        lock.lock()
        defer {
            lock.unlock()
        }

        loadPersistentCacheIfNeeded()

        var cacheChanged = false
        let roots = CodexUsageLogStore.rootDirectories(codexHome: codexHome)
        let files = roots.flatMap { root in
            CodexUsageLogStore.jsonlFiles(under: root, modifiedSince: modifiedSince)
        }
        let activePaths = Set(files.map { $0.url.path })
        if cachedFiles.contains(where: { !activePaths.contains($0.key) }) {
            cachedFiles = cachedFiles.filter { activePaths.contains($0.key) }
            cacheChanged = true
        }

        let events = files.flatMap { file in
            let key = file.url.path
            let fingerprint = FileFingerprint(
                modificationDate: file.modificationDate,
                fileSize: file.fileSize
            )
            if let cached = cachedFiles[key], cached.fingerprint == fingerprint {
                return cached.events
            }
            if let cached = cachedFiles[key],
               file.fileSize > cached.fingerprint.fileSize {
                let appendedEvents = eventReader(file.url, UInt64(cached.fingerprint.fileSize))
                let events = cached.events + appendedEvents
                cachedFiles[key] = CachedFile(fingerprint: fingerprint, events: events)
                cacheChanged = true
                return events
            }

            let events = eventReader(file.url, 0)
            cachedFiles[key] = CachedFile(fingerprint: fingerprint, events: events)
            cacheChanged = true
            return events
        }

        if cacheChanged {
            savePersistentCache()
        }
        return events
    }

    private func loadPersistentCacheIfNeeded() {
        guard !didLoadPersistentCache else {
            return
        }
        didLoadPersistentCache = true

        guard let persistentCacheURL,
              let data = try? Data(contentsOf: persistentCacheURL),
              let persistentCache = try? JSONDecoder().decode(PersistentCache.self, from: data),
              persistentCache.version == PersistentCache.currentVersion else {
            return
        }

        cachedFiles = persistentCache.files.mapValues { entry in
            CachedFile(
                fingerprint: FileFingerprint(
                    modificationDate: Date(timeIntervalSince1970: entry.modificationTime),
                    fileSize: entry.fileSize
                ),
                events: entry.events
            )
        }
    }

    private func savePersistentCache() {
        guard let persistentCacheURL else {
            return
        }

        let files = cachedFiles.mapValues { cached in
            PersistentCache.FileEntry(
                modificationTime: cached.fingerprint.modificationDate.timeIntervalSince1970,
                fileSize: cached.fingerprint.fileSize,
                events: cached.events
            )
        }
        let persistentCache = PersistentCache(version: PersistentCache.currentVersion, files: files)
        guard let data = try? JSONEncoder().encode(persistentCache) else {
            return
        }

        do {
            try FileManager.default.createDirectory(
                at: persistentCacheURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: persistentCacheURL, options: .atomic)
        } catch {
            return
        }
    }
}

private struct PersistentCache: Codable {
    struct FileEntry: Codable {
        let modificationTime: TimeInterval
        let fileSize: Int64
        let events: [CodexUsageEvent]
    }

    static let currentVersion = 1

    let version: Int
    let files: [String: FileEntry]
}
