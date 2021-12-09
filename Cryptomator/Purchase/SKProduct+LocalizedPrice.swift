//
//  SKProduct+LocalizedPrice.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 26.11.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation
import StoreKit

extension SKProduct {
	private static let formatter: NumberFormatter = {
		let formatter = NumberFormatter()
		formatter.numberStyle = .currency
		return formatter
	}()

	var localizedPrice: String? {
		let formatter = SKProduct.formatter
		formatter.locale = priceLocale
		return formatter.string(from: price)
	}
}
