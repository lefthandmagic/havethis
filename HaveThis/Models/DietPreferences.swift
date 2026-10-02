import Foundation

struct DietPreferences: Equatable, Codable {
    var skipMollusks: Bool
    var skipMushrooms: Bool

    /// Store default: nothing is skipped until someone turns it on.
    static let open = DietPreferences(skipMollusks: false, skipMushrooms: false)

    private static let key = "havethis.diet"

    static func load() -> DietPreferences {
        guard let data = UserDefaults.standard.data(forKey: key),
              let stored = try? JSONDecoder().decode(DietPreferences.self, from: data)
        else { return .open }
        return stored
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }
}
