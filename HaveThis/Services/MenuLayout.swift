import CoreGraphics
import Foundation

struct TextBlock: Equatable {
    var text: String
    var rect: CGRect
}

enum MenuLayout {
    /// Group OCR blocks that sit on the same horizontal band, left to right.
    static func lines(from blocks: [TextBlock]) -> [String] {
        let sorted = blocks
            .map { TextBlock(text: $0.text.trimmingCharacters(in: .whitespacesAndNewlines), rect: $0.rect) }
            .filter { !$0.text.isEmpty }
            .sorted { lhs, rhs in
                if abs(lhs.rect.midY - rhs.rect.midY) > 1 {
                    return lhs.rect.midY > rhs.rect.midY
                }
                return lhs.rect.minX < rhs.rect.minX
            }

        var rows: [[TextBlock]] = []
        for block in sorted {
            if let index = rows.indices.last {
                let band = max(rows[index][0].rect.height, block.rect.height, 12)
                if abs(rows[index][0].rect.midY - block.rect.midY) < band * 0.65 {
                    rows[index].append(block)
                    continue
                }
            }
            rows.append([block])
        }

        return rows.map { row in
            row.sorted { $0.rect.minX < $1.rect.minX }
                .map(\.text)
                .joined(separator: " ")
        }
    }
}
