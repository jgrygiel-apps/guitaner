import SwiftUI
import Combine

/// Single source of truth for the user's "Guitaner Pro" entitlement.
///
/// Today this is backed by `UserDefaults` and unlocked by a stub. When you add
/// real purchases (StoreKit 2 or RevenueCat), the *only* thing that changes is
/// the body of `purchase()`/`restore()` and how `isPro` gets its value — every
/// view that calls `hasAccess(to:)` keeps working unchanged.
@MainActor
final class ProStore: ObservableObject {

    /// Whether the user currently has Pro. Views observe this.
    @Published private(set) var isPro: Bool

    private let defaultsKey = "pro.isEntitled"

    init() {
        self.isPro = UserDefaults.standard.bool(forKey: defaultsKey)
    }

    /// Free features are always available; Pro features require entitlement.
    func hasAccess(to feature: ProFeature) -> Bool {
        isPro
    }

    // MARK: - Purchase flow (STUB)

    /// Kicks off the purchase. Replace the body with StoreKit/RevenueCat.
    ///
    /// Example (RevenueCat):
    /// ```
    /// let result = try await Purchases.shared.purchase(package: package)
    /// isPro = result.customerInfo.entitlements["pro"]?.isActive == true
    /// ```
    func purchase() async {
        // TODO: real payment. For now, unlock immediately so the flow is testable.
        setPro(true)
    }

    /// Restores a previous purchase (App Store requires a Restore button).
    func restore() async {
        // TODO: Purchases.shared.restorePurchases() → update isPro
        setPro(UserDefaults.standard.bool(forKey: defaultsKey))
    }

    // MARK: - Debug helpers

    /// Flip entitlement from a debug/settings screen while developing.
    func setPro(_ value: Bool) {
        isPro = value
        UserDefaults.standard.set(value, forKey: defaultsKey)
    }
}
