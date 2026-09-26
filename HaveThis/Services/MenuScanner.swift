import UIKit
import Vision

enum MenuScanner {
    static func lines(from image: UIImage) throws -> [String] {
        let upright = normalized(image)
        guard let cgImage = upright.cgImage else { throw OrderError.noText }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["nl-NL", "en-US"]

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
        try handler.perform([request])
        let observations = request.results ?? []
        let blocks: [TextBlock] = observations.compactMap { observation in
            guard let text = observation.topCandidates(1).first?.string else { return nil }
            return TextBlock(text: text, rect: observation.boundingBox)
        }
        let lines = MenuLineFilter.candidates(MenuLayout.lines(from: blocks))
        if lines.isEmpty { throw OrderError.noText }
        return lines
    }

    /// Redraw so pixel orientation is upright before Vision sees the image.
    private static func normalized(_ image: UIImage) -> UIImage {
        let maxSide: CGFloat = 2000
        let size = image.size
        let longest = max(size.width, size.height)
        let scale = longest > maxSide && longest > 0 ? maxSide / longest : 1
        let target = CGSize(width: max(size.width * scale, 1), height: max(size.height * scale, 1))
        let renderer = UIGraphicsImageRenderer(size: target)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
