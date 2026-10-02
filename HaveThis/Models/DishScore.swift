import Foundation

struct DishScore: Equatable, Codable {
    var name: String
    var protein: Double
    var fiber: Double
    var saturatedFat: Double
    var mollusk: Double
    var mushroom: Double

    /// Higher is a better plate: protein and fiber up, saturated fat down. Each part is 0–2, so the total is 0–6.
    var rank: Double {
        protein + fiber + (2 - saturatedFat)
    }

    /// Same three facts, shown as a single mark out of 10.
    var scoreOutOfTen: Double {
        let clamped = min(6, max(0, rank))
        return (clamped / 6) * 10
    }

    var scoreLabel: String {
        String(format: "%.1f", scoreOutOfTen)
    }

    /// One sentence a person can read, built from the three factor labels.
    var reason: String {
        let sentence = "\(Self.phrase(Self.band(protein), "protein")), \(Self.phrase(Self.band(fiber), "fiber")), \(Self.fatPhrase(Self.band(saturatedFat)))."
        return sentence.prefix(1).uppercased() + sentence.dropFirst()
    }

    var blocked: Bool {
        mollusk >= 0.55 || mushroom >= 0.55
    }

    var skipNote: String? {
        switch (mollusk >= 0.55, mushroom >= 0.55) {
        case (true, true): return "Mollusk and mushroom"
        case (true, false): return "Mollusk"
        case (false, true): return "Mushroom"
        case (false, false): return nil
        }
    }

    /// Jev's scale is 0 low, 1 moderate, 2 high.
    static func band(_ value: Double) -> String {
        switch Int(value.rounded()) {
        case ..<1: return "Low"
        case 1: return "Moderate"
        default: return "High"
        }
    }

    static func number(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private static func phrase(_ band: String, _ noun: String) -> String {
        switch band {
        case "High": return "high \(noun)"
        case "Low": return "low \(noun)"
        default: return "moderate \(noun)"
        }
    }

    private static func fatPhrase(_ band: String) -> String {
        switch band {
        case "High": return "higher saturated fat"
        case "Low": return "lower saturated fat"
        default: return "moderate saturated fat"
        }
    }
}

struct OrderResult: Equatable, Codable {
    var dishes: [DishScore]
    var skipped: [DishScore]
    /// Dishes on this photo that were past the scoring cap.
    var unscored: Int

    init(dishes: [DishScore], skipped: [DishScore], unscored: Int = 0) {
        self.dishes = dishes
        self.skipped = skipped
        self.unscored = unscored
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dishes = try container.decode([DishScore].self, forKey: .dishes)
        skipped = try container.decode([DishScore].self, forKey: .skipped)
        unscored = try container.decodeIfPresent(Int.self, forKey: .unscored) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(dishes, forKey: .dishes)
        try container.encode(skipped, forKey: .skipped)
        try container.encode(unscored, forKey: .unscored)
    }

    private enum CodingKeys: String, CodingKey {
        case dishes, skipped, unscored
    }
}

enum OrderError: LocalizedError {
    case noText
    case noDishes
    case allBlocked
    case missingKey
    case offline
    case jevDown
    case noScans
    case scoringFailed
    case provider(String)

    var errorDescription: String? {
        switch self {
        case .noText:
            return "Couldn't read a menu in that photo. Get closer, with the dishes in the frame."
        case .noDishes:
            return "No dishes left after filtering. Try another photo of the menu."
        case .allBlocked:
            return "What's left looks like mollusks or mushrooms. Try another photo."
        case .missingKey:
            return "This build is missing the scoring key."
        case .offline:
            return "No connection. The photo stayed on the phone. Try again when you're online."
        case .jevDown:
            return "Scoring is down right now. Nothing was used from your scans. Try again."
        case .noScans:
            return "No scans left. HaveThis Plus includes 30 a month, or you can add a pack of 10."
        case .scoringFailed:
            return "Scoring failed. Nothing was used from your scans. Try again."
        case .provider(let message):
            return message
        }
    }
}
