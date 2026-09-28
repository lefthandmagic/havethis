import Foundation

struct ScanTiming: Codable, Equatable {
    var photoSeconds: Double
    var jevSeconds: Double
    var serverSeconds: Double
    var calls: Int? = nil

    static func clock(_ seconds: Double) -> String {
        if seconds < 10 { return String(format: "%.1fs", seconds) }
        return String(format: "%.0fs", seconds)
    }

    var line: String {
        var text = "Photo \(Self.clock(photoSeconds)) · Jev \(Self.clock(jevSeconds))"
        if serverSeconds > 0.05 {
            text += " (\(Self.clock(serverSeconds)) on their side)"
        }
        if let calls, calls > 0 {
            text += calls == 1 ? " · 1 call" : " · \(calls) calls"
        }
        return text
    }
}

struct MenuSearch: Identifiable, Codable, Equatable {
    var id: UUID
    var createdAt: Date
    var result: OrderResult
    var timing: ScanTiming?

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
