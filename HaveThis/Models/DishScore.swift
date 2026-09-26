import Foundation

struct DishScore: Equatable {
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
}

struct OrderResult: Equatable {
    var pick: DishScore
    var alternatives: [DishScore]
    var reason: String
}

enum OrderError: LocalizedError {
    case noText
    case noDishes
    case allBlocked
    case missingKey
    case scoringFailed

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
        }
    }
}
