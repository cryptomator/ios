//
//  CloudProviderUpdatingMock.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 28.08.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

#if DEBUG
import Foundation

// swiftlint:disable all

final class CloudProviderUpdatingMock: CloudProviderUpdating {
	// MARK: - providerShouldUpdate

	var providerShouldUpdateWithCallsCount = 0
	var providerShouldUpdateWithCalled: Bool {
		providerShouldUpdateWithCallsCount > 0
	}

	var providerShouldUpdateWithReceivedAccountUID: String?
	var providerShouldUpdateWithReceivedInvocations: [String] = []
	var providerShouldUpdateWithClosure: ((String) -> Void)?

	func providerShouldUpdate(with accountUID: String) {
		providerShouldUpdateWithCallsCount += 1
		providerShouldUpdateWithReceivedAccountUID = accountUID
		providerShouldUpdateWithReceivedInvocations.append(accountUID)
		providerShouldUpdateWithClosure?(accountUID)
	}
}
// swiftlint:enable all
#endif
