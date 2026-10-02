import Foundation

enum MenuTitle {
    private static let headers: Set<String> = [
        "starter", "starters", "main", "mains", "dessert", "desserts",
        "drinks", "wine", "wines", "lunch", "dinner", "menu", "ontbijt",
        "voorgerechten", "hoofdgerechten", "nagerechten", "bijgerechten"
    ]

    /// A short place name from the top of the page, otherwise the two best dishes.
    static func suggest(from lines: [String], dishes: [DishScore], picks: [DishScore]) -> String {
        let named = Set(dishes.map { fold($0.name) })
        for line in lines.prefix(20) {
            guard let place = place(in: line) else { continue }
            if named.contains(fold(place)) { continue }
            return place
        }
        return fromDishes(picks)
    }

    static func fromDishes(_ dishes: [DishScore]) -> String {
        let names = dishes.prefix(2).map(\.name)
        switch names.count {
        case 0: return "Menu"
        case 1: return names[0]
        default: return "\(names[0]) and \(names[1])"
        }
    }

    private static func place(in line: String) -> String? {
        let text = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 3, text.count <= 36 else { return nil }
        guard text.rangeOfCharacter(from: .decimalDigits) == nil else { return nil }
        let words = text.split(whereSeparator: \.isWhitespace)
        guard (1...4).contains(words.count) else { return nil }
        let lower = text.lowercased()
        if headers.contains(lower) { return nil }
        if lower.contains("http") || lower.contains("www.") { return nil }
        return text
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
