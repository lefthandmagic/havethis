import PhotosUI
import SwiftUI
import UIKit

@MainActor
final class OrderModel: ObservableObject {
    enum Phase {
        case idle
        case working(String)
        case result(OrderResult)
        case failed(String)
    }

    @Published var phase: Phase = .idle
    @Published var source: MenuImageSource?

    var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func analyze(_ image: UIImage) async {
        phase = .working("Reading the menu")
        do {
            let lines = try MenuScanner.lines(from: image)
            phase = .working("Scoring dishes")
            let result = try await OrderEngine.order(from: lines)
            phase = .result(result)
        } catch let error as OrderError {
            phase = .failed(error.localizedDescription)
        } catch {
            phase = .failed(OrderError.scoringFailed.localizedDescription)
        }
    }
}

struct OrderView: View {
    @StateObject private var model = OrderModel()

    private let paper = Color(red: 0.965, green: 0.957, blue: 0.933)
    private let ink = Color(red: 0.180, green: 0.280, blue: 0.220)

    var body: some View {
        ZStack {
            paper.ignoresSafeArea()
            VStack(spacing: 28) {
                Spacer(minLength: 12)
                content
                Spacer(minLength: 12)
                if case .working = model.phase {
                    EmptyView()
                } else {
                    actionButtons
                }
            }
            .padding(28)
        }
        .fullScreenCover(item: $model.source) { source in
            picker(for: source)
                .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private func picker(for source: MenuImageSource) -> some View {
        switch source {
        case .camera:
            CameraPicker(
                onImage: { image in
                    model.source = nil
                    Task { await model.analyze(image) }
                },
                onCancel: { model.source = nil }
            )
        case .library:
            LibraryPicker(
                onImage: { image in
                    model.source = nil
                    Task { await model.analyze(image) }
                },
                onCancel: { model.source = nil }
            )
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .idle:
            VStack(spacing: 10) {
                Text("HaveThis")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(ink)
                Text("Take a photo of a menu, or choose one from your library.")
                    .font(.body)
                    .foregroundStyle(ink.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        case .working(let label):
            VStack(spacing: 16) {
                ProgressView()
                    .tint(ink)
                Text(label)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(ink)
            }
        case .result(let result):
            VStack(alignment: .leading, spacing: 18) {
                Text("Have this")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ink.opacity(0.65))
                Text(result.pick.name)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(result.reason)
                    .font(.body)
                    .foregroundStyle(ink.opacity(0.75))
                if !result.alternatives.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Also fine")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(ink.opacity(0.65))
                        ForEach(result.alternatives, id: \.name) { dish in
                            Text(dish.name)
                                .font(.body)
                                .foregroundStyle(ink)
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .failed(let message):
            Text(message)
                .font(.title3)
                .foregroundStyle(ink)
                .multilineTextAlignment(.center)
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if model.cameraAvailable {
                Button {
                    model.source = .camera
                } label: {
                    Text("Take a photo")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(ink)
            }
            Button {
                model.source = .library
            } label: {
                Text("Choose a photo")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.bordered)
            .tint(ink)
        }
    }
}

enum MenuImageSource: Identifiable {
    case camera
    case library

    var id: String {
        switch self {
        case .camera: return "camera"
        case .library: return "library"
        }
    }
}

struct LibraryPicker: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage, onCancel: onCancel)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onImage: (UIImage) -> Void
        let onCancel: () -> Void

        init(onImage: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onImage = onImage
            self.onCancel = onCancel
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else {
                onCancel()
                return
            }
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                DispatchQueue.main.async {
                    if let image = object as? UIImage {
                        self.onImage(image)
                    } else {
                        self.onCancel()
                    }
                }
            }
        }
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImage: (UIImage) -> Void
        let onCancel: () -> Void

        init(onImage: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onImage = onImage
            self.onCancel = onCancel
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onImage(image)
            } else {
                onCancel()
            }
        }
    }
}
