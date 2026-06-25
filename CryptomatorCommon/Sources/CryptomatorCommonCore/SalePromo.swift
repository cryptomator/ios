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
	public static let summer2026Emoji = "☀️"
	public static let summer2026Discount = "50%* off until July 7"

	public static func isSummer2026Active() -> Bool {
		let saleStartComponents = DateComponents(year: 2026, month: 7, day: 1)
		let saleEndComponents = DateComponents(year: 2026, month: 7, day: 8)
		let gregorian = Calendar(identifier: .gregorian)
		guard let saleStartDate = gregorian.date(from: saleStartComponents), let saleEndDate = gregorian.date(from: saleEndComponents) else {
			return false
		}
		let now = Date()
		return now >= saleStartDate && now < saleEndDate
	}

	public func shouldShowSummer2026Banner() -> Bool {
		#if !ALWAYS_PREMIUM
		return SalePromo.isSummer2026Active()
			&& !(cryptomatorSettings.fullVersionUnlocked || cryptomatorSettings.hasRunningSubscription)
			&& !cryptomatorSettings.summer2026BannerDismissed
		#else
		return false
		#endif
	}

	public func shouldShowSummer2026UnlockPromo() -> Bool {
		#if !ALWAYS_PREMIUM
		return SalePromo.isSummer2026Active()
			&& !(cryptomatorSettings.fullVersionUnlocked || cryptomatorSettings.hasRunningSubscription)
			&& !cryptomatorSettings.summer2026UnlockPromoShown
		#else
		return false
		#endif
	}
}
