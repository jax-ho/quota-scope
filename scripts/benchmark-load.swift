import Foundation

@main
struct Benchmark {
    static func main() {
        let now = Date()

        for index in 1...6 {
            let started = DispatchTime.now().uptimeNanoseconds
            let snapshot = CodexUsageLogStore.loadSnapshot(now: now)
            let ended = DispatchTime.now().uptimeNanoseconds
            let elapsedMilliseconds = Double(ended - started) / 1_000_000

            print(
                String(
                    format: "run %d: %.2f ms, events=%d, latestTokens=%d",
                    index,
                    elapsedMilliseconds,
                    snapshot.eventCount,
                    snapshot.latestEvent?.totalUsage.totalTokens ?? 0
                )
            )
        }
    }
}
