//
//  UnlockMonitorTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 31.01.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import XCTest
@testable import CryptomatorCommonCore
@testable import CryptomatorFileProvider

class UnlockMonitorTests: XCTestCase {
	let vaultUID = "VaultUID-12345"
	let defaultEnrolledBiometricsAuthenticationName = "Face ID"
	var taskExecutorMock: UnlockMonitorTaskExecutorMock!
	var passwordManagerMock: VaultPasswordManagerMock!
	var unlockMonitor: UnlockMonitor!

	override func setUpWithError() throws {
		taskExecutorMock = UnlockMonitorTaskExecutorMock()
		passwordManagerMock = VaultPasswordManagerMock()
		unlockMonitor = UnlockMonitor(taskExecutor: taskExecutorMock, vaultPasswordManager: passwordManagerMock)
		unlockMonitor.enrolledBiometricsAuthenticationName = { [weak self] in self?.defaultEnrolledBiometricsAuthenticationName }
	}

	func testStartBiometricalUnlock() {
		unlockMonitor.startBiometricalUnlock(forVaultUID: vaultUID)
		XCTAssertEqual(.biometricalUnlockStarted, unlockMonitor.unlockStates[vaultUID])
		XCTAssert(taskExecutorMock.runningBiometricalUnlock)
		XCTAssertFalse(passwordManagerMock.removePasswordForVaultUIDCalled)
	}

	func testEndBiometricalUnlock() {
		unlockMonitor.startBiometricalUnlock(forVaultUID: vaultUID)
		unlockMonitor.endBiometricalUnlock(forVaultUID: vaultUID)
		XCTAssertFalse(taskExecutorMock.runningBiometricalUnlock)
		XCTAssertFalse(passwordManagerMock.removePasswordForVaultUIDCalled)
	}

	func testWrongBiometricalPassword() {
		let expectedError: UnlockMonitorError = .biometricalUnlockWrongPassword(biometryName: defaultEnrolledBiometricsAuthenticationName)
		unlockMonitor.startBiometricalUnlock(forVaultUID: vaultUID)
		XCTAssertEqual(.biometricalUnlockStarted, unlockMonitor.unlockStates[vaultUID])
		unlockMonitor.unlockFailed(forVaultUID: vaultUID)
		XCTAssertEqual(.wrongPassword, unlockMonitor.unlockStates[vaultUID])
		unlockMonitor.endBiometricalUnlock(forVaultUID: vaultUID)
		XCTAssertEqual(.wrongPassword, unlockMonitor.unlockStates[vaultUID])
		XCTAssertEqual(expectedError, unlockMonitor.getUnlockError(forVaultUID: vaultUID))
		XCTAssert(passwordManagerMock.removePasswordForVaultUIDCalled)
	}

	func testBiometricalAuthCanceled() {
		unlockMonitor.startBiometricalUnlock(forVaultUID: vaultUID)
		unlockMonitor.endBiometricalUnlock(forVaultUID: vaultUID)
		XCTAssertEqual(.biometricalUnlockCanceled(biometryName: defaultEnrolledBiometricsAuthenticationName), unlockMonitor.getUnlockError(forVaultUID: vaultUID))
		XCTAssertFalse(passwordManagerMock.removePasswordForVaultUIDCalled)
	}

	func testBiometricalUnlockSucceeded() {
		unlockMonitor.startBiometricalUnlock(forVaultUID: vaultUID)
		unlockMonitor.unlockSucceeded(forVaultUID: vaultUID)
		unlockMonitor.endBiometricalUnlock(forVaultUID: vaultUID)
		XCTAssertNil(unlockMonitor.unlockStates[vaultUID])
		XCTAssertFalse(passwordManagerMock.removePasswordForVaultUIDCalled)
	}

	func testUnlockSucceededResetsUnlockState() {
		unlockMonitor.startBiometricalUnlock(forVaultUID: vaultUID)
		XCTAssertEqual(.biometricalUnlockStarted, unlockMonitor.unlockStates[vaultUID])
		unlockMonitor.unlockSucceeded(forVaultUID: vaultUID)
		XCTAssertNil(unlockMonitor.unlockStates[vaultUID])
		XCTAssertFalse(passwordManagerMock.removePasswordForVaultUIDCalled)
	}

	func testGetUnlockedErrorBiometricsNotEnrolled() {
		unlockMonitor.enrolledBiometricsAuthenticationName = { return nil }
		unlockMonitor.startBiometricalUnlock(forVaultUID: vaultUID)
		unlockMonitor.endBiometricalUnlock(forVaultUID: vaultUID)
		XCTAssertEqual(.defaultLock, unlockMonitor.getUnlockError(forVaultUID: vaultUID))
		XCTAssertFalse(passwordManagerMock.removePasswordForVaultUIDCalled)
	}
}
