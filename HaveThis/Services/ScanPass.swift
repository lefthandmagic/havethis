import Foundation
import StoreKit

/// StoreKit gate. Until the App Store products exist, scans stay open so TestFlight still works.
@MainActor
final class ScanPass: ObservableObject {
    static let monthlyID = "com.praveenmurugesan.HaveThis.plus.monthly"
    static let yearlyID = "com.praveenmurugesan.HaveThis.plus.yearly"
    static let packID = "com.praveenmurugesan.HaveThis.scans.10"

    @Published private(set) var products: [Product] = []
    @Published private(set) var plus = false
    @Published private(set) var plusUsed = 0
    @Published private(set) var packRemaining = 0
    @Published private(set) var purchasesAvailable = false
    @Published var lastError: String?

    private var periodEnd: Date?
    private var finishedPacks: Set<String> = []
    nonisolated(unsafe) private var updates: Task<Void, Never>?

    var canScan: Bool {
        ScanAllowance.canScan(
            purchasesAvailable: purchasesAvailable,
            plus: plus,
            plusUsed: plusUsed,
            packRemaining: packRemaining
        )
    }

    var plusRemaining: Int {
        plus ? max(0, ScanAllowance.plusScans - plusUsed) : 0
    }

    init() {
        let defaults = UserDefaults.standard
        plusUsed = defaults.integer(forKey: Key.plusUsed)
        packRemaining = defaults.integer(forKey: Key.packRemaining)
        periodEnd = defaults.object(forKey: Key.periodEnd) as? Date
        if let ids = defaults.stringArray(forKey: Key.finishedPacks) {
            finishedPacks = Set(ids)
        }
        updates = Task { await listen() }
        Task {
            await reload()
            await finishUnfinished()
        }
    }

    deinit {
        updates?.cancel()
    }

    func reload() async {
        do {
            let found = try await Product.products(for: [Self.monthlyID, Self.yearlyID, Self.packID])
            products = found.sorted { $0.id < $1.id }
            purchasesAvailable = !found.isEmpty
        } catch {
            products = []
            purchasesAvailable = false
        }
        await refreshEntitlement()
    }

    func purchase(_ product: Product) async {
        lastError = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try Self.verified(verification)
                await grant(transaction)
                await transaction.finish()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            lastError = "The purchase didn't go through. Try again."
        }
    }

    func restore() async {
        lastError = nil
        do {
            try await AppStore.sync()
            await refreshEntitlement()
        } catch {
            lastError = "Couldn't restore purchases. Try again."
        }
    }

    /// Call only after Jev returns a menu. A failed call leaves the allowance alone.
    func consumeSuccessfulScan() {
        guard purchasesAvailable else { return }
        guard let next = ScanAllowance.consume(plus: plus, plusUsed: plusUsed, packRemaining: packRemaining) else { return }
        plusUsed = next.plusUsed
        packRemaining = next.packRemaining
        save()
    }

    private func finishUnfinished() async {
        for await result in Transaction.unfinished {
            guard let transaction = try? Self.verified(result) else { continue }
            await grant(transaction)
            await transaction.finish()
        }
    }

    private func listen() async {
        for await update in Transaction.updates {
            guard let transaction = try? Self.verified(update) else { continue }
            await grant(transaction)
            await transaction.finish()
        }
    }

    private func refreshEntitlement() async {
        var subscribed = false
        var expiry: Date?
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? Self.verified(result) else { continue }
            guard transaction.productID == Self.monthlyID || transaction.productID == Self.yearlyID else { continue }
            subscribed = true
            expiry = transaction.expirationDate
        }
        if expiry != periodEnd {
            plusUsed = 0
            periodEnd = expiry
        }
        plus = subscribed
        save()
    }

    private func grant(_ transaction: Transaction) async {
        if transaction.productID == Self.packID {
            let token = String(transaction.id)
            if !finishedPacks.contains(token) {
                finishedPacks.insert(token)
                packRemaining += ScanAllowance.packSize
            }
        }
        await refreshEntitlement()
    }

    private func save() {
        let defaults = UserDefaults.standard
        defaults.set(plusUsed, forKey: Key.plusUsed)
        defaults.set(packRemaining, forKey: Key.packRemaining)
        defaults.set(periodEnd, forKey: Key.periodEnd)
        defaults.set(Array(finishedPacks), forKey: Key.finishedPacks)
    }

    private static func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified:
            throw OrderError.scoringFailed
        }
    }

    private enum Key {
        static let plusUsed = "havethis.plusUsed"
        static let packRemaining = "havethis.packRemaining"
        static let periodEnd = "havethis.plusPeriodEnd"
        static let finishedPacks = "havethis.finishedPacks"
    }
}
