//
//  SalePromo.swift
//  Cryptomator
//
//  Created by Tobias Hagemann on 17.03.25.
//  Copyright © 2025 Skymatic GmbH. All rights reserved.
//

import Dependencies
import Foundation

struct SalePromo {
	@Dependency(\.cryptomatorSettings) private var cryptomatorSettings

	static let shared = SalePromo()
	static let autumn2025Emoji = "🍁"
	static let autumn2025Discount = "25%* off until September 30"

	static func isAutumn2025Active() -> Bool {
		let saleStartComponents = DateComponents(year: 2025, month: 9, day: 22)
		let saleEndComponents = DateComponents(year: 2025, month: 9, day: 30)
		guard let saleStartDate = Calendar.current.date(from: saleStartComponents), let saleEndDate = Calendar.current.date(from: saleEndComponents) else {
			return false
		}
		let now = Date()
		return now >= saleStartDate && now <= saleEndDate
	}

	func shouldShowAutumn2025Banner() -> Bool {
		#if !ALWAYS_PREMIUM
		return SalePromo.isAutumn2025Active() && !(cryptomatorSettings.fullVersionUnlocked || cryptomatorSettings.hasRunningSubscription) && !cryptomatorSettings.autumn2025BannerDismissed
		#else
		return false
		#endif
	}
}
