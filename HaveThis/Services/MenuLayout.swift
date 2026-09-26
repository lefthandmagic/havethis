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
                let slack = max(lhs.rect.height, rhs.rect.height) * 0.45
                if abs(lhs.rect.midY - rhs.rect.midY) > slack {
                    return lhs.rect.midY > rhs.rect.midY
                }
                return lhs.rect.minX < rhs.rect.minX
            }

        var rows: [[TextBlock]] = []
        for block in sorted {
            if let index = rows.indices.last {
                let row = rows[index]
                let rowMid = row.map(\.rect.midY).reduce(0, +) / CGFloat(row.count)
                let rowHeight = row.map(\.rect.height).max() ?? block.rect.height
                let tolerance = max(rowHeight, block.rect.height) * 0.65
                if abs(rowMid - block.rect.midY) < tolerance {
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
