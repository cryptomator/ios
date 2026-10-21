//
//  StoreManager.swift
//  Cryptomator
//
//  Created by Tobias Hagemann on 30.08.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import CryptomatorCommonCore
import Foundation
import StoreKit

enum ProductIdentifier: String, CaseIterable {
	case fullVersion = "org.cryptomator.ios.iap.full_version"
	case thirtyDayTrial = "org.cryptomator.ios.iap.30_day_trial"
	case paidUpgrade = "org.cryptomator.ios.iap.paid_upgrade"
	case freeUpgrade = "org.cryptomator.ios.iap.free_upgrade"
	case yearlySubscription = "org.cryptomator.ios.iap.yearly_sub"
}

protocol IAPStore {
	func fetchProducts(with identifiers: [ProductIdentifier]) async throws -> SKProductsResponse
}

class StoreManager: NSObject, IAPStore {
	static let shared = StoreManager()

	private var runningRequests = [ObjectIdentifier: (request: SKProductsRequest, response: OneShotSignal<SKProductsResponse>)]()

	override private init() {}

	func fetchProducts(with identifiers: [ProductIdentifier]) async throws -> SKProductsResponse {
		let productIdentifiers = Set(identifiers.map { $0.rawValue })
		let productRequest = SKProductsRequest(productIdentifiers: productIdentifiers)
		let response = OneShotSignal<SKProductsResponse>()
		runningRequests[ObjectIdentifier(productRequest)] = (productRequest, response)
		productRequest.delegate = self
		productRequest.start()
		return try await response.value
	}
}

// MARK: - SKProductsRequestDelegate

extension StoreManager: SKProductsRequestDelegate {
	nonisolated func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
		let requestID = ObjectIdentifier(request)
		DispatchQueue.main.async {
			guard let runningRequest = self.runningRequests.removeValue(forKey: requestID) else {
				DDLogError("Missing running request for fulfilling SKProductsRequest")
				return
			}
			runningRequest.response.fulfill(response)
		}
	}
}

// MARK: - SKRequestDelegate

extension StoreManager: SKRequestDelegate {
	nonisolated func request(_ request: SKRequest, didFailWithError error: Error) {
		DDLogError("SKRequest failed with error: \(error)")
		let requestID = ObjectIdentifier(request)
		DispatchQueue.main.async {
			guard let runningRequest = self.runningRequests.removeValue(forKey: requestID) else {
				DDLogError("Missing running request for rejecting SKProductsRequest")
				return
			}
			runningRequest.response.reject(error)
		}
	}
}
