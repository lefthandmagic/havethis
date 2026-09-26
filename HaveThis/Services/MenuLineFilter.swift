import Foundation

enum MenuLineFilter {
    private static let headers: Set<String> = [
        "starter", "starters", "main", "mains", "main course", "main courses",
        "dessert", "desserts", "drink", "drinks", "wine", "wines", "wijnen", "wijn",
        "dranken", "voorgerecht", "voorgerechten", "hoofdgerecht", "hoofdgerechten",
        "nagerecht", "nagerechten", "bijgerecht", "bijgerechten", "lunch", "dinner",
        "ontbijt", "menu", "allergen", "allergens", "allergenen", "sides", "side",
        "snacks", "snack", "voorgerechtjes"
    ]

    private static let weekdays = [
        "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
        "maandag", "dinsdag", "woensdag", "donderdag", "vrijdag", "zaterdag", "zondag"
    ]

    /// Drop obvious non-dishes and trailing prices. Jev does the finer cut.
    static func candidates(_ lines: [String]) -> [String] {
        var seen = Set<String>()
        var kept: [String] = []
        for raw in lines {
            guard let cleaned = clean(raw) else { continue }
            let key = cleaned.lowercased()
            guard seen.insert(key).inserted else { continue }
            kept.append(cleaned)
        }
        return kept
    }

    static func clean(_ line: String) -> String? {
        var text = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        if let range = text.range(
            of: #"(?:€|eur)?\s*\d{1,4}(?:[.,]\d{1,2}|,-)?\s*$"#,
            options: [.regularExpression, .caseInsensitive]
        ) {
            text.removeSubrange(range)
        }
        text = text.trimmingCharacters(in: CharacterSet(charactersIn: ".-–—|•·: "))
        guard text.count >= 3, text.count <= 80 else { return nil }
        guard text.rangeOfCharacter(from: .letters) != nil else { return nil }

        let digits = text.filter(\.isNumber).count
        if digits * 2 > text.count { return nil }

        let lower = text.lowercased()
        if headers.contains(lower) { return nil }
        if isJunk(lower) { return nil }
        return text
    }

    private static func isJunk(_ lower: String) -> Bool {
        if lower.contains("http") || lower.contains("www.") || lower.contains("@") { return true }
        if lower.contains(".com") || lower.contains(".nl") { return true }
        if weekdays.contains(where: { lower.contains($0) }) { return true }
        if lower.contains("opening") || lower.contains("gesloten") || lower.contains("open daily") { return true }
        if lower.range(of: #"\b\d{4}\s?[a-z]{2}\b"#, options: .regularExpression) != nil { return true }
        if lower.range(of: #"\+?\d[\d\s\-()]{7,}"#, options: .regularExpression) != nil { return true }
        if lower.range(of: #"(straat|gracht|plein|laan|kade)\b.*\d"#, options: .regularExpression) != nil {
            return true
        }
        if lower.range(of: #"\bweg\s+\d"#, options: .regularExpression) != nil {
            return true
        }
        return false
    }
}
