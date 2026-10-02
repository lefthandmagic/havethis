import StoreKit
import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var pass: ScanPass
    var onClose: () -> Void

    private let ink = HaveThisColor.ink

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("A scan asks Jev to read the menu. That costs money to run, so new scans are part of HaveThis Plus.")
                        .font(.body)
                        .foregroundStyle(ink.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)

                    if pass.products.isEmpty {
                        Text("Purchases aren't available in this build yet. Scans still work until the App Store products are set up.")
                            .font(.body)
                            .foregroundStyle(ink)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        ForEach(orderedProducts, id: \.id) { product in
                            Button {
                                Task { await pass.purchase(product) }
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(product.displayName)
                                        .font(.headline)
                                    Text(detail(for: product))
                                        .font(.subheadline)
                                        .foregroundStyle(ink.opacity(0.7))
                                    Text(product.displayPrice)
                                        .font(.body.weight(.semibold))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                            }
                            .buttonStyle(.bordered)
                            .tint(ink)
                        }
                    }

                    if let lastError = pass.lastError {
                        Text(lastError)
                            .font(.subheadline)
                            .foregroundStyle(ink)
                    }

                    Button("Restore purchases") {
                        Task { await pass.restore() }
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(ink)
                }
                .padding(28)
            }
            .background(HaveThisColor.paper.ignoresSafeArea())
            .navigationTitle("HaveThis Plus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        onClose()
                        dismiss()
                    }
                }
            }
        }
    }

    private var orderedProducts: [Product] {
        pass.products.sorted { offerRank($0.id) < offerRank($1.id) }
    }

    private func offerRank(_ id: String) -> Int {
        switch id {
        case ScanPass.yearlyID: return 0
        case ScanPass.monthlyID: return 1
        default: return 2
        }
    }

    private func detail(for product: Product) -> String {
        switch product.id {
        case ScanPass.monthlyID:
            return "30 scans a month"
        case ScanPass.yearlyID:
            return "30 scans a month, billed yearly"
        case ScanPass.packID:
            return "10 extra scans"
        default:
            return product.description
        }
    }
}
