import Foundation

enum OrderEngine {
    static func order(from lines: [String], client: JevClient = JevClient()) async throws -> OrderResult {
        let dishes = try await client.keepDishes(lines)
        if dishes.isEmpty { throw OrderError.noDishes }
        let scored = try await client.scoreDishes(dishes)
        if scored.isEmpty { throw OrderError.scoringFailed }
        let result = OrderRanking.rank(from: scored)
        if result.dishes.isEmpty && result.skipped.isEmpty { throw OrderError.scoringFailed }
        return result
    }
}
