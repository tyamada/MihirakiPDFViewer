//
// TipSelectionView.swift
// MihirakiPDFViewer
//
// Copyright 2026 Takuma Yamada.
//

import StoreKit
import SwiftUI

struct TipSelectionView: View {
    let tipManager: TipManager
    @Environment(\.purchase) private var purchaseAction
    @Environment(\.colorScheme) private var colorScheme
    @State private var purchasingProductID: String?
    @State private var isShowingPromotionCodeRedemption = false

    private var settingsTextColor: Color {
        colorScheme == .dark ? .white : .black
    }

    var body: some View {
        List {
            Section {
                if let errorMessage = tipManager.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(settingsTextColor)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical)
                } else if tipManager.products.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding(.vertical)
                } else {
                    ForEach(
                        tipManager.products.filter { $0.id != TipManager.koyomiV2BadgeProductID },
                        id: \.id
                    ) { product in
                        HStack(spacing: 12) {
                            Image(tipIconName(for: product.id))
                                .resizable()
                                .scaledToFill()
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(tipDisplayName(for: product.id))
                                    .font(.headline)
                                Text(tipDescription(for: product.id))
                                    .font(.caption)
                                    .foregroundColor(settingsTextColor)
                            }
                            Spacer()
                            productAction(for: product)
                        }
                    }
                }

                Button(String(localized: "redeem_promotion_code", defaultValue: "Redeem Promotion Code")) {
                    isShowingPromotionCodeRedemption = true
                }
                .disabled(purchasingProductID != nil)
                .accessibilityIdentifier("redeemPromotionCodeButton")

                Button {
                    Task { await tipManager.restorePurchases() }
                } label: {
                    if tipManager.isRestoringPurchases {
                        HStack {
                            ProgressView()
                            Text(String(localized: "restoring_purchases", defaultValue: "Restoring Purchases…"))
                        }
                    } else {
                        Text(String(localized: "restore_purchases", defaultValue: "Restore Purchases"))
                    }
                }
                .disabled(tipManager.isRestoringPurchases || purchasingProductID != nil)
                .accessibilityIdentifier("restorePurchasesButton")

                if let restoreMessage = tipManager.restoreMessage {
                    Text(restoreMessage)
                        .font(.footnote)
                        .foregroundColor(settingsTextColor)
                }
            } footer: {
                Text(String(localized: "supporter_icon_purchase_description", defaultValue: "Each purchase permanently unlocks its supporter icon. Restore purchases on another device using the same Apple Account."))
                    .font(.body)
                    .foregroundColor(settingsTextColor)
            }

            if tipManager.isPurchased(TipManager.koyomiV2BadgeProductID) {
                Section {
                    HStack(spacing: 16) {
                        Image("KoyomiV2Badge")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 72, height: 72)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(localized: "koyomi_v2_badge_name", defaultValue: "Ver. 2.0 Release Commemorative Koyomi Badge"))
                                .font(.headline)
                            Text(String(localized: "promotion_code_badge", defaultValue: "Promotion code badge"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("ownedBadge_koyomiV2")
                } header: {
                    Text(String(localized: "owned_badges", defaultValue: "Owned Badges"))
                }
            }
        }
        .accessibilityIdentifier("tipSelectionScreen")
        .navigationTitle(String(localized: "tip_selection_title", defaultValue: "Support"))
        .offerCodeRedemption(isPresented: $isShowingPromotionCodeRedemption) { _ in
            // The transaction listener in TipManager applies successful redemptions.
        }
        .task {
            await tipManager.updateStorefront()
        }
    }

    private func tipIconName(for productID: String) -> String {
        switch productID {
        case "supporter_icon_bronze":
            "TipIconBronze"
        case "supporter_icon_silver":
            "TipIconSilver"
        case "supporter_icon_gold":
            "TipIconGold"
        default:
            "TipIconGold"
        }
    }

    private func tipDisplayName(for productID: String) -> LocalizedStringResource {
        switch productID {
        case "supporter_icon_bronze":
            "tip_100_name"
        case "supporter_icon_silver":
            "tip_500_name"
        case "supporter_icon_gold":
            "tip_1000_name"
        default:
            "tip_selection_title"
        }
    }

    private func tipDescription(for productID: String) -> LocalizedStringResource {
        switch productID {
        case "supporter_icon_bronze":
            "tip_100_description"
        case "supporter_icon_silver":
            "tip_500_description"
        case "supporter_icon_gold":
            "tip_1000_description"
        default:
            "developer_support_description"
        }
    }

    private func purchase(_ product: Product) {
        purchasingProductID = product.id
        Task {
            await tipManager.purchase(product, using: purchaseAction)
            purchasingProductID = nil
        }
    }

    @ViewBuilder
    private func productAction(for product: Product) -> some View {
        if purchasingProductID == product.id {
            ProgressView()
        } else if tipManager.isPurchased(product.id) {
            let iconName = TipManager.appIconName(for: product.id)
            if tipManager.currentAppIconName == iconName {
                Text(String(localized: "supporter_icon_in_use", defaultValue: "In Use"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Button(String(localized: "use_supporter_icon", defaultValue: "Use Icon")) {
                    Task { _ = await tipManager.changeAppIcon(named: iconName) }
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("useSupporterIconButton_\(product.id)")
            }
        } else {
            Button(product.displayPrice) {
                purchase(product)
            }
            .buttonStyle(.borderedProminent)
            .disabled(purchasingProductID != nil || tipManager.isRestoringPurchases)
            .accessibilityIdentifier("tipProductButton_\(product.id)")
        }
    }
}
