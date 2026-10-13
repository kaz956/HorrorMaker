//
//  EntitlementStore.swift
//  HorrorMaker
//
//  Created by Codex on 2026/04/02.
//

import Foundation
import Observation
import StoreKit

@MainActor
@Observable
final class EntitlementStore {
    private enum Keys {
        static let dailyResetDate = "entitlement.dailyResetDate"
        static let dailyStoriesRemaining = "entitlement.dailyStoriesRemaining"
        static let storyCredits = "entitlement.storyCredits"
    }

    var entitlement: AppEntitlement = .dailyFree
    var products: [Product] = []
    var storeMessage = "商品情報を読み込みます。"
    var isLoadingProducts = false
    var isPurchasing = false

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        refreshDailyAllowanceIfNeeded()
        entitlement.storyCredits = defaults.integer(forKey: Keys.storyCredits)
        entitlement.dailyStoriesRemaining = max(
            defaults.object(forKey: Keys.dailyStoriesRemaining) as? Int ?? entitlement.dailyStoriesRemaining,
            0
        )
    }

    func prepareStore() async {
        refreshDailyAllowanceIfNeeded()
        await loadProducts()
        await refreshPurchasedEntitlements()
    }

    func consumeStory() {
        refreshDailyAllowanceIfNeeded()

        if entitlement.hasUnlimitedAccess {
            return
        }

        if entitlement.dailyStoriesRemaining > 0 {
            entitlement.dailyStoriesRemaining -= 1
            defaults.set(entitlement.dailyStoriesRemaining, forKey: Keys.dailyStoriesRemaining)
            return
        }

        if entitlement.storyCredits > 0 {
            entitlement.storyCredits -= 1
            defaults.set(entitlement.storyCredits, forKey: Keys.storyCredits)
        }
    }

    func refreshDailyAllowanceIfNeeded(now: Date = .now) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let lastReset = defaults.object(forKey: Keys.dailyResetDate) as? Date

        guard lastReset == nil || !calendar.isDate(today, inSameDayAs: lastReset!) else {
            return
        }

        entitlement.dailyStoriesRemaining = 1
        defaults.set(today, forKey: Keys.dailyResetDate)
        defaults.set(entitlement.dailyStoriesRemaining, forKey: Keys.dailyStoriesRemaining)
    }

    func purchaseMonthly() async {
        await purchase(productID: PurchaseProductID.subscriptionMonthly)
    }

    func purchaseStoryPack() async {
        await purchase(productID: PurchaseProductID.storyPackTen)
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshPurchasedEntitlements()
            storeMessage = "購入情報を復元しました。"
        } catch {
            storeMessage = "復元に失敗しました。\(error.localizedDescription)"
        }
    }

    private func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            products = try await Product.products(for: [
                PurchaseProductID.subscriptionMonthly,
                PurchaseProductID.storyPackTen
            ])

            if products.isEmpty {
                storeMessage = "App Store Connectの商品IDを登録すると価格が反映されます。"
            } else {
                storeMessage = "商品情報を取得しました。"
            }
        } catch {
            storeMessage = "商品情報の取得に失敗しました。\(error.localizedDescription)"
        }
    }

    private func refreshPurchasedEntitlements() async {
        var hasUnlimitedAccess = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }

            switch transaction.productID {
            case PurchaseProductID.subscriptionMonthly:
                hasUnlimitedAccess = true
            case PurchaseProductID.storyPackTen:
                break
            default:
                break
            }
        }

        entitlement.hasUnlimitedAccess = hasUnlimitedAccess
        entitlement.canUseSpatialAudio = hasUnlimitedAccess
        entitlement.maxKeywordCount = hasUnlimitedAccess ? 8 : 3
    }

    private func purchase(productID: String) async {
        guard let product = products.first(where: { $0.id == productID }) else {
            storeMessage = "商品が見つかりません。App Store ConnectのID設定を確認してください。"
            return
        }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    storeMessage = "購入検証に失敗しました。"
                    return
                }

                await apply(transaction: transaction)
                await transaction.finish()
            case .userCancelled:
                storeMessage = "購入をキャンセルしました。"
            case .pending:
                storeMessage = "購入が保留中です。承認後に反映されます。"
            @unknown default:
                storeMessage = "不明な購入結果です。"
            }
        } catch {
            storeMessage = "購入に失敗しました。\(error.localizedDescription)"
        }
    }

    private func apply(transaction: Transaction) async {
        switch transaction.productID {
        case PurchaseProductID.subscriptionMonthly:
            entitlement.hasUnlimitedAccess = true
            entitlement.canUseSpatialAudio = true
            entitlement.maxKeywordCount = 8
            storeMessage = "Horror+ が有効になりました。"
        case PurchaseProductID.storyPackTen:
            entitlement.storyCredits += 10
            defaults.set(entitlement.storyCredits, forKey: Keys.storyCredits)
            storeMessage = "10話パックを追加しました。"
        default:
            break
        }
    }
}
