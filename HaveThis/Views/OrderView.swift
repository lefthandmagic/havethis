import PhotosUI
import SwiftUI
import UIKit

@MainActor
final class OrderModel: ObservableObject {
    enum Phase {
        case idle
        case working(WorkStatus)
        case failed(String)
    }

    @Published var phase: Phase = .idle
    @Published var source: MenuImageSource?
    @Published var history: [MenuSearch]
    @Published var path = NavigationPath()
    @Published var diet: DietPreferences
    @Published var alertMessage: String?
    @Published var requestPaywall = false
    /// When set, the next photo is added to this scan instead of starting a new one.
    var mergingInto: UUID?

    let scanPass = ScanPass()

    init() {
        history = MenuHistory.load()
        diet = DietPreferences.load()
    }

    var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func analyze(_ image: UIImage) async {
        if !scanPass.canScan {
            requestPaywall = true
            return
        }
        let merging = mergingInto
        mergingInto = nil
        let photoStarted = Date()
        phase = .working(WorkStatus(
            title: "Reading the menu",
            detail: "On this phone",
            photoSeconds: nil,
            photoStarted: photoStarted,
            jevSeconds: 0,
            serverSeconds: 0,
            jevStarted: nil
        ))
        do {
            let lines = try MenuScanner.lines(from: image)
            let photoSeconds = Date().timeIntervalSince(photoStarted)
            phase = .working(WorkStatus(
                title: "Finding dishes",
                detail: "Checking which lines are dishes",
                photoSeconds: photoSeconds,
                photoStarted: nil,
                jevSeconds: 0,
                serverSeconds: 0,
                jevStarted: Date()
            ))
            let (result, stats) = try await OrderEngine.order(from: lines, preferences: diet) { update in
                Task { @MainActor in
                    self.phase = .working(WorkStatus(
                        title: update.title,
                        detail: update.detail,
                        photoSeconds: photoSeconds,
                        photoStarted: nil,
                        jevSeconds: update.completedRoundTrip,
                        serverSeconds: update.completedServer,
                        jevStarted: update.callStarted
                    ))
                }
            }
            let timing = ScanTiming(
                photoSeconds: photoSeconds,
                jevSeconds: stats.roundTrip,
                serverSeconds: stats.server,
                calls: stats.calls
            )
            if let merging, let index = history.firstIndex(where: { $0.id == merging }) {
                history[index].result = MenuMerge.combining(history[index].result, with: result)
            } else {
                let search = MenuSearch(id: UUID(), createdAt: Date(), result: result, timing: timing)
                history.insert(search, at: 0)
                if history.count > 40 { history = Array(history.prefix(40)) }
                path.append(search.id)
            }
            MenuHistory.save(history)
            scanPass.consumeSuccessfulScan()
            phase = .idle
        } catch let error as OrderError {
            fail(error.localizedDescription, merging: merging != nil)
        } catch {
            fail(OrderError.scoringFailed.localizedDescription, merging: merging != nil)
        }
    }

    private func fail(_ message: String, merging: Bool) {
        phase = merging ? .idle : .failed(message)
        if merging { alertMessage = message }
    }
}

struct WorkStatus: Equatable {
    var title: String
    var detail: String
    var photoSeconds: Double?
    var photoStarted: Date?
    var jevSeconds: Double
    var serverSeconds: Double
    var jevStarted: Date?
}

struct OrderView: View {
    @StateObject private var model = OrderModel()
    @State private var showSettings = false
    @State private var showPaywall = false
    @State private var addPhoto = false

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
                    RankedMenuView(
                        result: search.result,
                        createdAt: search.createdAt,
                        timing: search.timing,
                        preferences: model.diet,
                        busy: workingTitle
                    ) {
                        guard model.scanPass.canScan else {
                            showPaywall = true
                            return
                        }
                        model.mergingInto = id
                        addPhoto = true
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(diet: $model.diet, pass: model.scanPass) {
                    showSettings = false
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(pass: model.scanPass) {
                    showPaywall = false
                }
            }
            .confirmationDialog("Add to this menu", isPresented: $addPhoto, titleVisibility: .visible) {
                if model.cameraAvailable {
                    Button("Take a photo") { model.source = .camera }
                }
                Button("Choose a photo") { model.source = .library }
                Button("Cancel", role: .cancel) { model.mergingInto = nil }
            }
            .onChange(of: model.requestPaywall) { _, requested in
                if requested {
                    showPaywall = true
                    model.requestPaywall = false
                }
            }
            .alert("Couldn't score that photo", isPresented: alertShown) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(model.alertMessage ?? "")
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
                onCancel: {
                    model.source = nil
                    model.mergingInto = nil
                }
            )
        case .library:
            LibraryPicker(
                onImage: { image in
                    model.source = nil
                    Task { await model.analyze(image) }
                },
                onCancel: {
                    model.source = nil
                    model.mergingInto = nil
                }
            )
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .idle:
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    Text("HaveThis")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(ink)
                    Spacer()
                    Button("Settings") { showSettings = true }
                        .font(.body.weight(.semibold))
                        .foregroundStyle(ink)
                }
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
        case .working(let status):
            TimelineView(.periodic(from: .now, by: 0.1)) { context in
                workingStatus(status, now: context.date)
            }
        case .failed(let message):
            Text(message)
                .font(.title3)
                .foregroundStyle(ink)
                .multilineTextAlignment(.center)
        }
    }

    private func workingStatus(_ status: WorkStatus, now: Date) -> some View {
        #if DEBUG
        let photo = status.photoSeconds ?? status.photoStarted.map { now.timeIntervalSince($0) } ?? 0
        let jev = status.jevSeconds + (status.jevStarted.map { now.timeIntervalSince($0) } ?? 0)
        #endif
        return VStack(alignment: .leading, spacing: 22) {
            ProgressView()
                .tint(ink)
            VStack(alignment: .leading, spacing: 6) {
                Text(status.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(ink)
                Text(status.detail)
                    .font(.body)
                    .foregroundStyle(ink.opacity(0.7))
            }
            #if DEBUG
            VStack(alignment: .leading, spacing: 8) {
                clockRow("Photo", ScanTiming.clock(photo))
                clockRow("Jev", status.photoSeconds == nil ? "—" : ScanTiming.clock(jev))
                if status.serverSeconds > 0.05 {
                    clockRow("Their side", ScanTiming.clock(status.serverSeconds))
                }
            }
            Text("Photo is reading the picture on this phone. Jev is the wait. Their side is the slowest call Jev reported.")
                .font(.footnote)
                .foregroundStyle(ink.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
            #else
            EmptyView()
            #endif
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func clockRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .frame(width: 92, alignment: .leading)
            Text(value)
                .monospacedDigit()
            Spacer()
        }
        .font(.body.weight(.semibold))
        .foregroundStyle(ink)
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if model.cameraAvailable {
                Button {
                    startScan(.camera)
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
                startScan(.library)
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

    private var workingTitle: String? {
        if case .working(let status) = model.phase { return status.title }
        return nil
    }

    private var alertShown: Binding<Bool> {
        Binding(
            get: { model.alertMessage != nil },
            set: { if !$0 { model.alertMessage = nil } }
        )
    }

    private func startScan(_ source: MenuImageSource) {
        guard model.scanPass.canScan else {
            showPaywall = true
            return
        }
        model.mergingInto = nil
        model.source = source
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
