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
	static let winter2025Emoji = "❄️"
	static let winter2025Discount = "50%* off until December 31"

	static func isWinter2025Active() -> Bool {
		let saleStartComponents = DateComponents(year: 2025, month: 12, day: 1)
		let saleEndComponents = DateComponents(year: 2025, month: 12, day: 31)
		guard let saleStartDate = Calendar.current.date(from: saleStartComponents), let saleEndDate = Calendar.current.date(from: saleEndComponents) else {
			return false
		}
		let now = Date()
		return now >= saleStartDate && now <= saleEndDate
	}

	func shouldShowWinter2025Banner() -> Bool {
		#if !ALWAYS_PREMIUM
		return SalePromo.isWinter2025Active() && !(cryptomatorSettings.fullVersionUnlocked || cryptomatorSettings.hasRunningSubscription) && !cryptomatorSettings.winter2025BannerDismissed
		#else
		return false
		#endif
	}
}
