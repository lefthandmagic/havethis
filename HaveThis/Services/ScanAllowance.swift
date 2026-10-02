import Foundation

/// Local stand-in for the scan ledger. The server replaces this later.
enum ScanAllowance {
    static let plusScans = 30
    static let packSize = 10

    /// Plus scans are used first. A failed Jev call must not call this.
    static func consume(plus: Bool, plusUsed: Int, packRemaining: Int) -> (plusUsed: Int, packRemaining: Int)? {
        if plus, plusUsed < plusScans {
            return (plusUsed + 1, packRemaining)
        }
        if packRemaining > 0 {
            return (plusUsed, packRemaining - 1)
        }
        return nil
    }

    static func canScan(purchasesAvailable: Bool, plus: Bool, plusUsed: Int, packRemaining: Int) -> Bool {
        if !purchasesAvailable { return true }
        if plus, plusUsed < plusScans { return true }
        return packRemaining > 0
    }
}
