import SwiftUI

struct SettingsView: View {
    @Binding var diet: DietPreferences
    @ObservedObject var pass: ScanPass
    var onClose: () -> Void
    @State private var showPlus = false

    private let ink = HaveThisColor.ink

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Scans")
                            .font(.headline)
                            .foregroundStyle(ink)
                        Text(scanLine)
                            .font(.body)
                            .foregroundStyle(ink.opacity(0.75))
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Restore purchases") {
                            Task { await pass.restore() }
                        }
                        .font(.body.weight(.semibold))
                        .foregroundStyle(ink)
                        if let lastError = pass.lastError {
                            Text(lastError)
                                .font(.subheadline)
                                .foregroundStyle(ink)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Skip")
                            .font(.headline)
                            .foregroundStyle(ink)
                        Text("Off until you turn them on. Turn one on and matching dishes move to Skip.")
                            .font(.body)
                            .foregroundStyle(ink.opacity(0.75))
                            .fixedSize(horizontal: false, vertical: true)
                        Toggle("Mollusks", isOn: $diet.skipMollusks)
                        Toggle("Mushrooms", isOn: $diet.skipMushrooms)
                            .tint(ink)
                    }
                    .tint(ink)

                    Button("HaveThis Plus") { showPlus = true }
                        .font(.body.weight(.semibold))
                        .foregroundStyle(ink)

                    NavigationLink("Privacy") {
                        PrivacyView()
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(ink)

                    Link("Email support", destination: URL(string: "mailto:lefthandmagic@gmail.com?subject=HaveThis")!)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(ink)
                }
                .padding(28)
            }
            .background(HaveThisColor.paper.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onClose)
                }
            }
            .onChange(of: diet) { _, updated in
                updated.save()
            }
            .sheet(isPresented: $showPlus) {
                PaywallView(pass: pass) { showPlus = false }
            }
        }
    }

    private var scanLine: String {
        if !pass.purchasesAvailable {
            return "Purchases aren't on in this build yet, so scans aren't limited."
        }
        if pass.plus {
            return "Plus: \(pass.plusRemaining) of \(ScanAllowance.plusScans) left this period. Extra scans: \(pass.packRemaining)."
        }
        return "Extra scans: \(pass.packRemaining)."
    }
}

struct PrivacyView: View {
    private let ink = HaveThisColor.ink

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("The menu photo stays on your phone. HaveThis reads the text there.")
                Text("Dish names are sent to Jev so they can be scored. Prices, the photo, and your name are not.")
                Text("Scores are a guess from the dish name. They are not a lab result and not medical advice.")
                Text("Purchases are handled by Apple. HaveThis does not run its own account.")
            }
            .font(.body)
            .foregroundStyle(ink.opacity(0.85))
            .fixedSize(horizontal: false, vertical: true)
            .padding(28)
        }
        .background(HaveThisColor.paper.ignoresSafeArea())
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}
