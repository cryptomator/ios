//
//  HubVaultUnlockHandlerDelegateMock.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 19.11.23.
//  Copyright © 2023 Skymatic GmbH. All rights reserved.

import Foundation
@testable import CryptomatorCommonCore

// swiftlint:disable all
final class HubVaultUnlockHandlerDelegateMock: HubVaultUnlockHandlerDelegate {
	// MARK: - successfullyProcessedUnlockedVault

	var successfullyProcessedUnlockedVaultCallsCount = 0
	var successfullyProcessedUnlockedVaultCalled: Bool {
		successfullyProcessedUnlockedVaultCallsCount > 0
	}

	var successfullyProcessedUnlockedVaultClosure: (() -> Void)?

	func successfullyProcessedUnlockedVault() {
		successfullyProcessedUnlockedVaultCallsCount += 1
		successfullyProcessedUnlockedVaultClosure?()
	}

	// MARK: - failedToProcessUnlockedVault

	var failedToProcessUnlockedVaultErrorCallsCount = 0
	var failedToProcessUnlockedVaultErrorCalled: Bool {
		failedToProcessUnlockedVaultErrorCallsCount > 0
	}

	var failedToProcessUnlockedVaultErrorReceivedError: Error?
	var failedToProcessUnlockedVaultErrorReceivedInvocations: [Error] = []
	var failedToProcessUnlockedVaultErrorClosure: ((Error) -> Void)?

	func failedToProcessUnlockedVault(error: Error) {
		failedToProcessUnlockedVaultErrorCallsCount += 1
		failedToProcessUnlockedVaultErrorReceivedError = error
		failedToProcessUnlockedVaultErrorReceivedInvocations.append(error)
		failedToProcessUnlockedVaultErrorClosure?(error)
	}
}

// swiftlint:enable all
