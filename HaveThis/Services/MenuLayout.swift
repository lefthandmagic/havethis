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
            .flatMap(splitNewlines)
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
                let tolerance = max(rowHeight, block.rect.height) * 0.4
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

    /// Vision sometimes returns several menu lines as one block, with newlines between them.
    private static func splitNewlines(_ block: TextBlock) -> [TextBlock] {
        let parts = block.text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard parts.count > 1 else { return [block] }
        let height = block.rect.height / CGFloat(parts.count)
        return parts.enumerated().map { index, text in
            let maxY = block.rect.maxY - height * CGFloat(index)
            return TextBlock(
                text: text,
                rect: CGRect(x: block.rect.minX, y: maxY - height, width: block.rect.width, height: height)
            )
        }
    }
}
