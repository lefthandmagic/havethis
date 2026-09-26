import Foundation

struct DishScore: Equatable, Codable {
    var name: String
    var protein: Double
    var fiber: Double
    var saturatedFat: Double
    var mollusk: Double
    var mushroom: Double

    /// Higher is a better plate: protein and fiber up, saturated fat down.
    var rank: Double {
        protein + fiber + (2 - saturatedFat)
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
}

struct OrderResult: Equatable, Codable {
    var dishes: [DishScore]
    var skipped: [DishScore]
}

enum OrderError: LocalizedError {
    case noText
    case noDishes
    case allBlocked
    case missingKey
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
        case .scoringFailed:
            return "Scoring failed. Check the connection and try again."
        case .provider(let message):
            return message
        }
    }
}
