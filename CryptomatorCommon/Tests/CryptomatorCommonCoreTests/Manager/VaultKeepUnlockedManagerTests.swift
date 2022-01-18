//
//  VaultKeepUnlockedManagerTests.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 04.01.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import XCTest
@testable import CryptomatorCommonCore

class VaultKeepUnlockedManagerTests: XCTestCase {
	var cryptomatorKeychainMock: CryptomatorKeychainMock!
	var vaultKeepUnlockedManager: VaultKeepUnlockedManager!
	let vaultUID = "VaultUID-12345"
	var keepUnlockedDurationKey: String {
		return "\(vaultUID)-keepUnlockedDuration"
	}

	var lastUsedDateKey: String {
		return "\(vaultUID)-lastUsedDate"
	}

	override func setUpWithError() throws {
		cryptomatorKeychainMock = CryptomatorKeychainMock()
		vaultKeepUnlockedManager = VaultKeepUnlockedManager(keychain: cryptomatorKeychainMock)
	}

	// MARK: Auto-Lock timeout

	func testSetKeepUnlockedDuration() throws {
		let keepUnlockedDuration = KeepUnlockedDuration.fiveMinutes
		try vaultKeepUnlockedManager.setKeepUnlockedDuration(keepUnlockedDuration, forVaultUID: vaultUID)

		XCTAssertEqual(1, cryptomatorKeychainMock.setValueCallsCount)
		XCTAssertEqual(keepUnlockedDurationKey, cryptomatorKeychainMock.setValueReceivedArguments?.key)
		let passedValue = try XCTUnwrap(cryptomatorKeychainMock.setValueReceivedArguments?.value)
		XCTAssertEqual(keepUnlockedDuration, try JSONDecoder().decode(KeepUnlockedDuration.self, from: passedValue))
	}

	func testGetKeepUnlockedDuration() throws {
		let keepUnlockedDuration = KeepUnlockedDuration.fiveMinutes
		let keepUnlockedDurationJSON = try JSONEncoder().encode(keepUnlockedDuration)
		cryptomatorKeychainMock.getAsDataReturnValue = keepUnlockedDurationJSON
		let retrievedKeepUnlockedDuration = vaultKeepUnlockedManager.getKeepUnlockedDuration(forVaultUID: vaultUID)

		XCTAssertEqual(keepUnlockedDuration, retrievedKeepUnlockedDuration)
		XCTAssertEqual(1, cryptomatorKeychainMock.getAsDataCallsCount)
		XCTAssertEqual(keepUnlockedDurationKey, cryptomatorKeychainMock.getAsDataReceivedKey)
	}

	func testGetKeepUnlockedDurationNotSet() throws {
		cryptomatorKeychainMock.getAsDataReturnValue = nil
		let retrievedKeepUnlockedDuration = vaultKeepUnlockedManager.getKeepUnlockedDuration(forVaultUID: vaultUID)

		XCTAssertEqual(.auto, retrievedKeepUnlockedDuration)
		XCTAssertEqual(1, cryptomatorKeychainMock.getAsDataCallsCount)
		XCTAssertEqual(keepUnlockedDurationKey, cryptomatorKeychainMock.getAsDataReceivedKey)
	}

	func testRemoveKeepUnlockedDuration() throws {
		try vaultKeepUnlockedManager.removeKeepUnlockedDuration(forVaultUID: vaultUID)
		XCTAssertEqual(1, cryptomatorKeychainMock.deleteCallsCount)
		XCTAssertEqual(keepUnlockedDurationKey, cryptomatorKeychainMock.deleteReceivedKey)
	}

	// MARK: Last used date

	func testSetLastUsedDate() throws {
		let lastUsedDate = Date(timeIntervalSince1970: 0)
		try vaultKeepUnlockedManager.setLastUsedDate(lastUsedDate, forVaultUID: vaultUID)

		XCTAssertEqual(1, cryptomatorKeychainMock.setValueCallsCount)
		XCTAssertEqual(lastUsedDateKey, cryptomatorKeychainMock.setValueReceivedArguments?.key)
		let passedValue = try XCTUnwrap(cryptomatorKeychainMock.setValueReceivedArguments?.value)
		XCTAssertEqual(lastUsedDate, try JSONDecoder().decode(Date.self, from: passedValue))
	}

	func testGetLastUsedDate() throws {
		let lastUsedDate = Date(timeIntervalSince1970: 0)
		let lastUsedDateJSON = try JSONEncoder().encode(lastUsedDate)
		cryptomatorKeychainMock.getAsDataReturnValue = lastUsedDateJSON

		let retrievedLastUsedDate = vaultKeepUnlockedManager.getLastUsedDate(forVaultUID: vaultUID)
		XCTAssertEqual(lastUsedDate, retrievedLastUsedDate)
		XCTAssertEqual(1, cryptomatorKeychainMock.getAsDataCallsCount)
		XCTAssertEqual(lastUsedDateKey, cryptomatorKeychainMock.getAsDataReceivedKey)
	}

	func testGetLastUsedDateNoEntry() throws {
		cryptomatorKeychainMock.getAsDataReturnValue = nil

		let retrievedLastUsedDate = vaultKeepUnlockedManager.getLastUsedDate(forVaultUID: vaultUID)
		XCTAssertNil(retrievedLastUsedDate)
		XCTAssertEqual(1, cryptomatorKeychainMock.getAsDataCallsCount)
		XCTAssertEqual(lastUsedDateKey, cryptomatorKeychainMock.getAsDataReceivedKey)
	}

	// MARK: Should Auto-Lock Vault

	func testShouldAutoLockVault() throws {
		cryptomatorKeychainMock.getAsDataClosure = { key in
			switch key {
			case self.keepUnlockedDurationKey:
				let keepUnlockedDuration = KeepUnlockedDuration.fiveMinutes
				return try? JSONEncoder().encode(keepUnlockedDuration)
			case self.lastUsedDateKey:
				let lastUsedDate = Date().addingTimeInterval(-59)
				return try? JSONEncoder().encode(lastUsedDate)
			default:
				return nil
			}
		}
		XCTAssertFalse(vaultKeepUnlockedManager.shouldAutoLockVault(withVaultUID: vaultUID))
		XCTAssertEqual(2, cryptomatorKeychainMock.getAsDataCallsCount)
		XCTAssertEqual([keepUnlockedDurationKey, lastUsedDateKey], cryptomatorKeychainMock.getAsDataReceivedInvocations)
	}

	func testShouldAutoLockVaultNoLastUsedDateSet() throws {
		cryptomatorKeychainMock.getAsDataClosure = { key in
			switch key {
			case self.keepUnlockedDurationKey:
				let keepUnlockedDuration = KeepUnlockedDuration.fiveMinutes
				return try? JSONEncoder().encode(keepUnlockedDuration)
			case self.lastUsedDateKey:
				return nil
			default:
				return nil
			}
		}
		XCTAssert(vaultKeepUnlockedManager.shouldAutoLockVault(withVaultUID: vaultUID))
		XCTAssertEqual(2, cryptomatorKeychainMock.getAsDataCallsCount)
		XCTAssertEqual([keepUnlockedDurationKey, lastUsedDateKey], cryptomatorKeychainMock.getAsDataReceivedInvocations)
	}

	func testShouldAutoLockVaultLastUsedDateDistantPast() throws {
		cryptomatorKeychainMock.getAsDataClosure = { key in
			switch key {
			case self.keepUnlockedDurationKey:
				let keepUnlockedDuration = KeepUnlockedDuration.fiveMinutes
				return try? JSONEncoder().encode(keepUnlockedDuration)
			case self.lastUsedDateKey:
				let lastUsedDate = Date.distantPast
				return try? JSONEncoder().encode(lastUsedDate)
			default:
				return nil
			}
		}
		XCTAssert(vaultKeepUnlockedManager.shouldAutoLockVault(withVaultUID: vaultUID))
		XCTAssertEqual(2, cryptomatorKeychainMock.getAsDataCallsCount)
		XCTAssertEqual([keepUnlockedDurationKey, lastUsedDateKey], cryptomatorKeychainMock.getAsDataReceivedInvocations)
	}

	func testShouldAutoLockVaultLastUsedDateTooLate() throws {
		cryptomatorKeychainMock.getAsDataClosure = { key in
			switch key {
			case self.keepUnlockedDurationKey:
				let keepUnlockedDuration = KeepUnlockedDuration.fiveMinutes
				return try? JSONEncoder().encode(keepUnlockedDuration)
			case self.lastUsedDateKey:
				let lastUsedDate = Date().addingTimeInterval(-60 * 5)
				return try? JSONEncoder().encode(lastUsedDate)
			default:
				return nil
			}
		}
		XCTAssert(vaultKeepUnlockedManager.shouldAutoLockVault(withVaultUID: vaultUID))
		XCTAssertEqual(2, cryptomatorKeychainMock.getAsDataCallsCount)
		XCTAssertEqual([keepUnlockedDurationKey, lastUsedDateKey], cryptomatorKeychainMock.getAsDataReceivedInvocations)
	}

	func testShouldAutoLockVaultWithKeepUnlockedDurationNotSet() throws {
		cryptomatorKeychainMock.getAsDataClosure = { key in
			switch key {
			case self.keepUnlockedDurationKey:
				return nil
			case self.lastUsedDateKey:
				return nil
			default:
				return nil
			}
		}
		XCTAssertFalse(vaultKeepUnlockedManager.shouldAutoLockVault(withVaultUID: vaultUID))
		XCTAssertEqual(1, cryptomatorKeychainMock.getAsDataCallsCount)
		XCTAssertEqual([keepUnlockedDurationKey], cryptomatorKeychainMock.getAsDataReceivedInvocations)
	}

	func testShouldAutoLockVaultWithKeepUnlockedDurationNever() throws {
		cryptomatorKeychainMock.getAsDataClosure = { key in
			switch key {
			case self.keepUnlockedDurationKey:
				let keepUnlockedDuration = KeepUnlockedDuration.indefinite
				return try? JSONEncoder().encode(keepUnlockedDuration)
			case self.lastUsedDateKey:
				return nil
			default:
				return nil
			}
		}
		XCTAssertFalse(vaultKeepUnlockedManager.shouldAutoLockVault(withVaultUID: vaultUID))
		XCTAssertEqual(1, cryptomatorKeychainMock.getAsDataCallsCount)
		XCTAssertEqual([keepUnlockedDurationKey], cryptomatorKeychainMock.getAsDataReceivedInvocations)
	}

	// MARK: Should Auto-Unlock Vault

	func testShouldAutoUnlockVaultWithKeepUnlockedDurationNotSet() {
		cryptomatorKeychainMock.getAsDataClosure = { key in
			switch key {
			case self.keepUnlockedDurationKey:
				return nil
			case self.lastUsedDateKey:
				return nil
			default:
				return nil
			}
		}
		XCTAssertFalse(vaultKeepUnlockedManager.shouldAutoUnlockVault(withVaultUID: vaultUID))
		XCTAssertEqual(1, cryptomatorKeychainMock.getAsDataCallsCount)
		XCTAssertEqual([keepUnlockedDurationKey], cryptomatorKeychainMock.getAsDataReceivedInvocations)
	}

	func testShouldAutoUnlockVaultWithKeepUnlockedDurationNever() {
		cryptomatorKeychainMock.getAsDataClosure = { key in
			switch key {
			case self.keepUnlockedDurationKey:
				let keepUnlockedDuration = KeepUnlockedDuration.indefinite
				return try? JSONEncoder().encode(keepUnlockedDuration)
			case self.lastUsedDateKey:
				return nil
			default:
				return nil
			}
		}
		XCTAssert(vaultKeepUnlockedManager.shouldAutoUnlockVault(withVaultUID: vaultUID))
		XCTAssertEqual(1, cryptomatorKeychainMock.getAsDataCallsCount)
		XCTAssertEqual([keepUnlockedDurationKey], cryptomatorKeychainMock.getAsDataReceivedInvocations)
	}

	func testShouldAutoUnlockVaultWithShouldAutoLock() {
		cryptomatorKeychainMock.getAsDataClosure = { key in
			switch key {
			case self.keepUnlockedDurationKey:
				let keepUnlockedDuration = KeepUnlockedDuration.fiveMinutes
				return try? JSONEncoder().encode(keepUnlockedDuration)
			case self.lastUsedDateKey:
				return nil
			default:
				return nil
			}
		}
		let vaultKeepUnlockedManager = VaultKeepUnlockedManagerShouldAutoLockMocked(shouldAutoLockVault: true, keychain: cryptomatorKeychainMock)
		XCTAssertFalse(vaultKeepUnlockedManager.shouldAutoUnlockVault(withVaultUID: vaultUID))
		XCTAssertEqual(1, cryptomatorKeychainMock.getAsDataCallsCount)
		XCTAssertEqual([keepUnlockedDurationKey], cryptomatorKeychainMock.getAsDataReceivedInvocations)
	}

	func testShouldAutoUnlockVaultWithShouldNotAutoLock() {
		cryptomatorKeychainMock.getAsDataClosure = { key in
			switch key {
			case self.keepUnlockedDurationKey:
				let keepUnlockedDuration = KeepUnlockedDuration.fiveMinutes
				return try? JSONEncoder().encode(keepUnlockedDuration)
			case self.lastUsedDateKey:
				return nil
			default:
				return nil
			}
		}
		let vaultKeepUnlockedManager = VaultKeepUnlockedManagerShouldAutoLockMocked(shouldAutoLockVault: false, keychain: cryptomatorKeychainMock)
		XCTAssert(vaultKeepUnlockedManager.shouldAutoUnlockVault(withVaultUID: vaultUID))
		XCTAssertEqual(1, cryptomatorKeychainMock.getAsDataCallsCount)
		XCTAssertEqual([keepUnlockedDurationKey], cryptomatorKeychainMock.getAsDataReceivedInvocations)
	}
}

private class VaultKeepUnlockedManagerShouldAutoLockMocked: VaultKeepUnlockedManager {
	private let shouldAutoLockVaultReturnValue: Bool

	init(shouldAutoLockVault: Bool, keychain: CryptomatorKeychainType) {
		self.shouldAutoLockVaultReturnValue = shouldAutoLockVault
		super.init(keychain: keychain)
	}

	override func shouldAutoLockVault(withVaultUID vaultUID: String) -> Bool {
		return shouldAutoLockVaultReturnValue
	}
}
