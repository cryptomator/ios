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
	public static let halloween2026Emoji = "🎃"
	public static let halloween2026Discount = "33%* off until October 31"

	public static func isHalloween2026Active() -> Bool {
		let saleStartComponents = DateComponents(year: 2026, month: 10, day: 1)
		let saleEndComponents = DateComponents(year: 2026, month: 11, day: 1)
		let gregorian = Calendar(identifier: .gregorian)
		guard let saleStartDate = gregorian.date(from: saleStartComponents), let saleEndDate = gregorian.date(from: saleEndComponents) else {
			return false
		}
		let now = Date()
		return now >= saleStartDate && now < saleEndDate
	}

	public func shouldShowHalloween2026Banner() -> Bool {
		#if !ALWAYS_PREMIUM
		return SalePromo.isHalloween2026Active()
			&& !(cryptomatorSettings.fullVersionUnlocked || cryptomatorSettings.hasRunningSubscription)
			&& !cryptomatorSettings.halloween2026BannerDismissed
		#else
		return false
		#endif
	}

	public func shouldShowHalloween2026UnlockPromo() -> Bool {
		#if !ALWAYS_PREMIUM
		return SalePromo.isHalloween2026Active()
			&& !(cryptomatorSettings.fullVersionUnlocked || cryptomatorSettings.hasRunningSubscription)
			&& !cryptomatorSettings.halloween2026UnlockPromoShown
		#else
		return false
		#endif
	}
}
