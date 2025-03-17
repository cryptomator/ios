//
//  SalePromo.swift
//  Cryptomator
//
//  Created by Tobias Hagemann on 17.03.25.
//  Copyright © 2025 Skymatic GmbH. All rights reserved.
//

#if !ALWAYS_PREMIUM
import Dependencies
import Foundation

struct SalePromo {
	@Dependency(\.cryptomatorSettings) private var cryptomatorSettings

	static let shared = SalePromo()
	static let spring2025Emoji = "🌸"
	static let spring2025Discount = "25%* off until March 31"

	static func isSpring2025Active() -> Bool {
		let saleStartComponents = DateComponents(year: 2025, month: 3, day: 20)
		let saleEndComponents = DateComponents(year: 2025, month: 3, day: 31)
		guard let saleStartDate = Calendar.current.date(from: saleStartComponents), let saleEndDate = Calendar.current.date(from: saleEndComponents) else {
			return false
		}
		let now = Date()
		return now >= saleStartDate && now <= saleEndDate
	}

	func shouldShowSpring2025Banner() -> Bool {
		return SalePromo.isSpring2025Active() && !(cryptomatorSettings.fullVersionUnlocked || cryptomatorSettings.hasRunningSubscription) && !cryptomatorSettings.spring2025BannerDismissed
	}
}
#endif
