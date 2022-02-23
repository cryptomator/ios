//
//  StoreManager.swift
//  Cryptomator
//
//  Created by Tobias Hagemann on 30.08.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import Foundation
import Promises
import StoreKit

enum ProductIdentifier: String, CaseIterable {
	case fullVersion = "org.cryptomator.ios.iap.full_version"
	case thirtyDayTrial = "org.cryptomator.ios.iap.30_day_trial"
	case paidUpgrade = "org.cryptomator.ios.iap.paid_upgrade"
	case freeUpgrade = "org.cryptomator.ios.iap.free_upgrade"
	case yearlySubscription = "org.cryptomator.ios.iap.yearly_sub"
}

protocol IAPStore {
	func fetchProducts(with identifiers: [ProductIdentifier]) -> Promise<SKProductsResponse>
}

class StoreManager: NSObject, IAPStore {
	static let shared = StoreManager()

	private var runningRequests = [SKProductsRequest: Promise<SKProductsResponse>]()

	override private init() {}

	func fetchProducts(with identifiers: [ProductIdentifier]) -> Promise<SKProductsResponse> {
		let productIdentifiers = Set(identifiers.map { $0.rawValue })
		let productRequest = SKProductsRequest(productIdentifiers: productIdentifiers)
		let pendingPromise = Promise<SKProductsResponse>.pending()
		runningRequests[productRequest] = pendingPromise
		productRequest.delegate = self
		productRequest.start()
		return pendingPromise
	}
}

// MARK: - SKProductsRequestDelegate

extension StoreManager: SKProductsRequestDelegate {
	func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
		guard let promise = runningRequests.removeValue(forKey: request) else {
			DDLogError("Missing running request for fulfilling SKProductsRequest promise")
			return
		}
		promise.fulfill(response)
	}
}

// MARK: - SKRequestDelegate

extension StoreManager: SKRequestDelegate {
	func request(_ request: SKRequest, didFailWithError error: Error) {
		DDLogError("SKRequest failed with error: \(error)")
		guard let productRequest = request as? SKProductsRequest, let promise = runningRequests.removeValue(forKey: productRequest) else {
			DDLogError("Missing running request for rejecting SKProductsRequest promise")
			return
		}
		promise.reject(error)
	}
}
