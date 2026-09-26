import Foundation

struct MenuSearch: Identifiable, Codable, Equatable {
    var id: UUID
    var createdAt: Date
    var result: OrderResult

    var title: String {
        result.dishes.first?.name ?? result.skipped.first?.name ?? "Menu"
    }
}

enum MenuHistory {
    private static let maxItems = 40

    static func load() -> [MenuSearch] {
        guard let data = try? Data(contentsOf: file) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([MenuSearch].self, from: data)) ?? []
    }

    static func save(_ items: [MenuSearch]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(Array(items.prefix(maxItems))) else { return }
        try? FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: file, options: .atomic)
    }

    private static var file: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("HaveThis", isDirectory: true).appendingPathComponent("history.json")
    }
}
