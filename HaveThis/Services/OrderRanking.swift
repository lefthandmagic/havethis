import Foundation

enum OrderRanking {
    static func rank(from dishes: [DishScore]) -> OrderResult {
        OrderResult(
            dishes: dishes.filter { !$0.blocked }.sorted(by: better),
            skipped: dishes.filter(\.blocked).sorted(by: better)
        )
    }

    private static func better(_ lhs: DishScore, _ rhs: DishScore) -> Bool {
        if lhs.rank == rhs.rank { return lhs.name < rhs.name }
        return lhs.rank > rhs.rank
    }
}
