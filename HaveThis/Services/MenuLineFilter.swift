import Foundation

enum MenuLineFilter {
    private static let headers: Set<String> = [
        "starter", "starters", "main", "mains", "main course", "main courses",
        "dessert", "desserts", "drink", "drinks", "wine", "wines", "wijnen", "wijn",
        "dranken", "voorgerecht", "voorgerechten", "hoofdgerecht", "hoofdgerechten",
        "nagerecht", "nagerechten", "bijgerecht", "bijgerechten", "lunch", "dinner",
        "ontbijt", "menu", "allergen", "allergens", "allergenen", "sides", "side",
        "snacks", "snack", "voorgerechtjes",
        "appetizer", "appetizers", "veg appetizers", "vegetarian appetizers",
        "non-veg appetizers", "non veg appetizers"
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
            for piece in separateDishes(raw) {
            guard let cleaned = clean(piece) else { continue }
            let key = cleaned.lowercased()
            guard seen.insert(key).inserted else { continue }
            kept.append(cleaned)
            }
        }
        return kept
    }

    /// "Oysters 18 Mussels 16 Frites 7" is three dishes the camera read as one line.
    static func separateDishes(_ line: String) -> [String] {
        let pattern = #"(?i)(?:€\s*)?\d{1,3}(?:[.,]\d{1,2}|,-)?(?=\s+\p{Lu})"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [line] }
        let ns = line as NSString
        let matches = regex.matches(in: line, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return [line] }
        var parts: [String] = []
        var start = 0
        for match in matches {
            let end = match.range.location + match.range.length
            let piece = ns.substring(with: NSRange(location: start, length: end - start))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !piece.isEmpty { parts.append(piece) }
            start = end
        }
        let tail = ns.substring(from: start).trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { parts.append(tail) }
        return parts.count > 1 ? parts : [line]
    }

    static func clean(_ line: String) -> String? {
        var text = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        if let range = text.range(
            of: #"(?:(?:€|eur)\s*\d{1,4}(?:[.,]\d{1,2})?|\d{1,4}[.,]\d{1,2}|\d{1,4},-|\d{1,3})\s*$"#,
            options: [.regularExpression, .caseInsensitive]
        ) {
            text.removeSubrange(range)
        }
        text = text.replacingOccurrences(
            of: #"^\d{2,4}\s+"#,
            with: "",
            options: .regularExpression
        )
        if let heading = headingPrefix(in: text) {
            text = heading
        }
        text = text.trimmingCharacters(in: CharacterSet(charactersIn: ".-–—|•·: "))
        guard text.count >= 3, text.count <= 160 else { return nil }
        guard text.rangeOfCharacter(from: .letters) != nil else { return nil }

        let digits = text.filter(\.isNumber).count
        if digits * 2 > text.count { return nil }

        let lower = text.lowercased()
        if headers.contains(lower) { return nil }
        if isJunk(lower) { return nil }
        return text
    }

    /// Keep an ALL-CAPS dish name when a description was glued on the same line.
    private static func headingPrefix(in text: String) -> String? {
        let words = text.split(whereSeparator: \.isWhitespace).map(String.init)
        var kept: [String] = []
        for word in words {
            if isHeadingWord(word) {
                kept.append(word)
                continue
            }
            break
        }
        guard !kept.isEmpty else { return nil }
        let prefix = kept.joined(separator: " ")
        guard prefix.count >= 3, prefix.count < text.count else { return nil }
        let letters = prefix.filter(\.isLetter)
        let upper = letters.filter(\.isUppercase).count
        guard !letters.isEmpty, upper * 2 >= letters.count else { return nil }
        return prefix
    }

    private static func isHeadingWord(_ word: String) -> Bool {
        let letters = word.filter(\.isLetter)
        if letters.isEmpty { return !word.isEmpty }
        let upper = letters.filter(\.isUppercase).count
        let lower = letters.count - upper
        if upper == 0 || upper < lower { return false }
        if letters.count >= 4 && upper <= lower { return false }
        return true
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
