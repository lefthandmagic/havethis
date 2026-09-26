import PhotosUI
import SwiftUI
import UIKit

@MainActor
final class OrderModel: ObservableObject {
    enum Phase {
        case idle
        case working(String)
        case failed(String)
    }

    @Published var phase: Phase = .idle
    @Published var source: MenuImageSource?
    @Published var history: [MenuSearch]
    @Published var path = NavigationPath()

    init() {
        history = MenuHistory.load()
    }

    var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func analyze(_ image: UIImage) async {
        phase = .working("Reading the menu")
        do {
            let lines = try MenuScanner.lines(from: image)
            phase = .working("Scoring dishes")
            let result = try await OrderEngine.order(from: lines)
            let search = MenuSearch(id: UUID(), createdAt: Date(), result: result)
            history.insert(search, at: 0)
            if history.count > 40 { history = Array(history.prefix(40)) }
            MenuHistory.save(history)
            phase = .idle
            path.append(search.id)
        } catch let error as OrderError {
            phase = .failed(error.localizedDescription)
        } catch {
            phase = .failed(OrderError.scoringFailed.localizedDescription)
        }
    }
}

struct OrderView: View {
    @StateObject private var model = OrderModel()

    private var paper: Color { HaveThisColor.paper }
    private var ink: Color { HaveThisColor.ink }

    var body: some View {
        NavigationStack(path: $model.path) {
            ZStack {
                paper.ignoresSafeArea()
                VStack(spacing: 28) {
                    content
                    if case .working = model.phase {
                        EmptyView()
                    } else {
                        actionButtons
                    }
                }
                .padding(28)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: UUID.self) { id in
                if let search = model.history.first(where: { $0.id == id }) {
                    RankedMenuView(result: search.result, createdAt: search.createdAt)
                }
            }
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
            VStack(alignment: .leading, spacing: 18) {
                Text("HaveThis")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(ink)
                if model.history.isEmpty {
                    Text("Take a photo of a menu, or choose one from your library.")
                        .font(.body)
                        .foregroundStyle(ink.opacity(0.7))
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(model.history) { search in
                                Button {
                                    model.path.append(search.id)
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(search.title)
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(ink)
                                            .multilineTextAlignment(.leading)
                                            .lineLimit(2)
                                        Text(search.createdAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(.subheadline)
                                            .foregroundStyle(ink.opacity(0.65))
                                        Text("\(search.result.dishes.count) ranked")
                                            .font(.subheadline)
                                            .foregroundStyle(ink.opacity(0.65))
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        case .working(let label):
            VStack(spacing: 16) {
                Spacer()
                ProgressView()
                    .tint(ink)
                Text(label)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(ink)
                Spacer()
            }
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
