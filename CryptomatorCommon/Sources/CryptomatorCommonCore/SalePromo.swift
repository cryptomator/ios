//
//  SalePromo.swift
//  CryptomatorCommonCore
//
//  Created by Tobias Hagemann on 17.03.25.
//  Copyright © 2025 Skymatic GmbH. All rights reserved.
//

import Dependencies
import Foundation

public struct SalePromo {
	@Dependency(\.cryptomatorSettings) private var cryptomatorSettings

	public static let shared = SalePromo()
	public static let tenthAnniversaryEmoji = "🎉"
	public static let tenthAnniversaryDiscount = "67%* off until March 18"

	public static func isTenthAnniversaryActive() -> Bool {
		let saleStartComponents = DateComponents(year: 2026, month: 3, day: 9)
		let saleEndComponents = DateComponents(year: 2026, month: 3, day: 19)
		let gregorian = Calendar(identifier: .gregorian)
		guard let saleStartDate = gregorian.date(from: saleStartComponents), let saleEndDate = gregorian.date(from: saleEndComponents) else {
			return false
		}
		let now = Date()
		return now >= saleStartDate && now < saleEndDate
	}

	public func shouldShowTenthAnniversaryBanner() -> Bool {
		#if !ALWAYS_PREMIUM
		return SalePromo.isTenthAnniversaryActive()
			&& !(cryptomatorSettings.fullVersionUnlocked || cryptomatorSettings.hasRunningSubscription)
			&& !cryptomatorSettings.tenthAnniversaryBannerDismissed
		#else
		return false
		#endif
	}

	public func shouldShowTenthAnniversaryUnlockPromo() -> Bool {
		#if !ALWAYS_PREMIUM
		return SalePromo.isTenthAnniversaryActive()
			&& !(cryptomatorSettings.fullVersionUnlocked || cryptomatorSettings.hasRunningSubscription)
			&& !cryptomatorSettings.tenthAnniversaryUnlockPromoShown
		#else
		return false
		#endif
	}
}
