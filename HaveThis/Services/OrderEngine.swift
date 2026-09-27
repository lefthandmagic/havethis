import Foundation

enum OrderEngine {
    static func order(
        from lines: [String],
        client: JevClient = JevClient(),
        progress: (@Sendable (JevProgress) -> Void)? = nil
    ) async throws -> (result: OrderResult, stats: JevCallStats) {
        let (dishes, found) = try await client.keepDishes(lines, progress: progress)
        if dishes.isEmpty { throw OrderError.noDishes }
        let (scored, scoredStats) = try await client.scoreDishes(dishes, progress: progress)
        if scored.isEmpty { throw OrderError.scoringFailed }
        let result = OrderRanking.rank(from: scored)
        if result.dishes.isEmpty && result.skipped.isEmpty { throw OrderError.scoringFailed }
        return (result, found + scoredStats)
    }
}
