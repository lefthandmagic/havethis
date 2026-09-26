import Foundation

enum OrderRanking {
    static func pick(from dishes: [DishScore]) -> OrderResult? {
        let open = dishes
            .filter { !$0.blocked }
            .sorted { lhs, rhs in
                if lhs.rank == rhs.rank { return lhs.name < rhs.name }
                return lhs.rank > rhs.rank
            }
        guard let first = open.first else { return nil }
        return OrderResult(
            pick: first,
            alternatives: Array(open.dropFirst().prefix(2)),
            reason: reason(for: first)
        )
    }

    static func reason(for dish: DishScore) -> String {
        var bits: [String] = []
        if dish.protein >= 1.2 { bits.append("higher protein") }
        if dish.fiber >= 1.2 { bits.append("more fiber") }
        if dish.saturatedFat <= 0.8 { bits.append("lighter on saturated fat") }
        guard let first = bits.first else { return "The best of this menu." }
        let rest = bits.dropFirst()
        if rest.isEmpty { return first.prefix(1).uppercased() + first.dropFirst() + "." }
        let sentence = first + ", " + rest.joined(separator: ", ")
        return sentence.prefix(1).uppercased() + sentence.dropFirst() + "."
    }
}
