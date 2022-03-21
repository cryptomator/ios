//
//  PremiumManagerMock.swift
//  CryptomatorTests
//
//  Created by Philipp Schmid on 21.02.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import Foundation
@testable import Cryptomator

final class PremiumManagerTypeMock: PremiumManagerType {
	// MARK: - refreshStatus

	var refreshStatusCallsCount = 0
	var refreshStatusCalled: Bool {
		refreshStatusCallsCount > 0
	}

	var refreshStatusClosure: (() -> Void)?

	func refreshStatus() {
		refreshStatusCallsCount += 1
		refreshStatusClosure?()
	}

	// MARK: - trialExpirationDate

	var trialExpirationDateForCallsCount = 0
	var trialExpirationDateForCalled: Bool {
		trialExpirationDateForCallsCount > 0
	}

	var trialExpirationDateForReceivedPurchaseDate: Date?
	var trialExpirationDateForReceivedInvocations: [Date] = []
	var trialExpirationDateForReturnValue: Date?
	var trialExpirationDateForClosure: ((Date) -> Date?)?

	func trialExpirationDate(for purchaseDate: Date) -> Date? {
		trialExpirationDateForCallsCount += 1
		trialExpirationDateForReceivedPurchaseDate = purchaseDate
		trialExpirationDateForReceivedInvocations.append(purchaseDate)
		return trialExpirationDateForClosure.map({ $0(purchaseDate) }) ?? trialExpirationDateForReturnValue
	}
}
