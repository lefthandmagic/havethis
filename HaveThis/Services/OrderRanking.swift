import Foundation

enum OrderRanking {
    static func rank(from dishes: [DishScore], preferences: DietPreferences = .open) -> OrderResult {
        OrderResult(
            dishes: dishes.filter { !blocked($0, preferences) }.sorted(by: better),
            skipped: dishes.filter { blocked($0, preferences) }.sorted(by: better)
        )
    }

    static func blocked(_ dish: DishScore, _ preferences: DietPreferences) -> Bool {
        (preferences.skipMollusks && dish.mollusk >= 0.55)
            || (preferences.skipMushrooms && dish.mushroom >= 0.55)
    }

    private static func better(_ lhs: DishScore, _ rhs: DishScore) -> Bool {
        if lhs.rank == rhs.rank { return lhs.name < rhs.name }
        return lhs.rank > rhs.rank
    }
}

enum MenuMerge {
    static func combining(_ base: OrderResult, with addition: OrderResult) -> OrderResult {
        var seen = Set<String>()
        var all: [DishScore] = []
        for dish in base.dishes + base.skipped + addition.dishes + addition.skipped {
            let key = dish.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            if seen.insert(key).inserted {
                all.append(dish)
            }
        }
        return OrderResult(
            dishes: all,
            skipped: [],
            unscored: base.unscored + addition.unscored
        )
    }
}
