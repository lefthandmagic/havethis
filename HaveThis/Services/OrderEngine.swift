import Foundation

enum OrderEngine {
    static func order(from lines: [String], client: JevClient = JevClient()) async throws -> OrderResult {
        let dishes = try await client.keepDishes(lines)
        if dishes.isEmpty { throw OrderError.noDishes }
        let scored = try await client.scoreDishes(dishes)
        if scored.isEmpty { throw OrderError.scoringFailed }
        guard let result = OrderRanking.pick(from: scored) else { throw OrderError.allBlocked }
        return result
    }
}
