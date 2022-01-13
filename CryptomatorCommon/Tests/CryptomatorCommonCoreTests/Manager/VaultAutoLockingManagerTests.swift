//
//  VaultAutoLockingManagerTests.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 04.01.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import XCTest
@testable import CryptomatorCommonCore

class VaultAutoLockingManagerTests: XCTestCase {
	var cryptomatorKeychainMock: CryptomatorKeychainMock!
	var vaultAutoLockingManager: VaultAutoLockingManager!
	let vaultUID = "VaultUID-12345"
	var autoLockKey: String {
		return "\(vaultUID)-autoLockDuration"
	}

	var lastUsedDateKey: String {
		return "\(vaultUID)-lastUsedDate"
	}

	override func setUpWithError() throws {
		cryptomatorKeychainMock = CryptomatorKeychainMock()
		vaultAutoLockingManager = VaultAutoLockingManager(keychain: cryptomatorKeychainMock)
	}

	// MARK: Auto-Lock timeout

	func testSetKeepUnlockedSetting() throws {
		let keepUnlockedSetting = KeepUnlockedSetting.oneMinute
		try vaultAutoLockingManager.setKeepUnlockedSetting(keepUnlockedSetting, forVaultUID: vaultUID)

		XCTAssertEqual(1, cryptomatorKeychainMock.setValueCallsCount)
		XCTAssertEqual(autoLockKey, cryptomatorKeychainMock.setValueReceivedArguments?.key)
		let passedValue = try XCTUnwrap(cryptomatorKeychainMock.setValueReceivedArguments?.value)
		XCTAssertEqual(keepUnlockedSetting, try JSONDecoder().decode(KeepUnlockedSetting.self, from: passedValue))
	}

	func testGetKeepUnlockedSetting() throws {
		let keepUnlockedSetting = KeepUnlockedSetting.oneMinute
		let keepUnlockedSettingJSON = try JSONEncoder().encode(keepUnlockedSetting)
		cryptomatorKeychainMock.getAsDataReturnValue = keepUnlockedSettingJSON
		let retrievedKeepUnlockedSetting = vaultAutoLockingManager.getKeepUnlockedSetting(forVaultUID: vaultUID)

		XCTAssertEqual(keepUnlockedSetting, retrievedKeepUnlockedSetting)
		XCTAssertEqual(1, cryptomatorKeychainMock.getAsDataCallsCount)
		XCTAssertEqual(autoLockKey, cryptomatorKeychainMock.getAsDataReceivedKey)
	}

	func testGetKeepUnlockedSettingNotSet() throws {
		cryptomatorKeychainMock.getAsDataReturnValue = nil
		let retrievedKeepUnlockedSetting = vaultAutoLockingManager.getKeepUnlockedSetting(forVaultUID: vaultUID)

		XCTAssertEqual(vaultAutoLockingManager.defaultKeepUnlockedSetting, retrievedKeepUnlockedSetting)
		XCTAssertEqual(1, cryptomatorKeychainMock.getAsDataCallsCount)
		XCTAssertEqual(autoLockKey, cryptomatorKeychainMock.getAsDataReceivedKey)
	}

	func testRemoveKeepUnlockedSetting() throws {
		try vaultAutoLockingManager.removeKeepUnlockedSetting(forVaultUID: vaultUID)
		XCTAssertEqual(1, cryptomatorKeychainMock.deleteCallsCount)
		XCTAssertEqual(autoLockKey, cryptomatorKeychainMock.deleteReceivedKey)
	}

	// MARK: Last used date

	func testSetLastUsedDate() throws {
		let lastUsedDate = Date(timeIntervalSince1970: 0)
		try vaultAutoLockingManager.setLastUsedDate(lastUsedDate, forVaultUID: vaultUID)

		XCTAssertEqual(1, cryptomatorKeychainMock.setValueCallsCount)
		XCTAssertEqual(lastUsedDateKey, cryptomatorKeychainMock.setValueReceivedArguments?.key)
		let passedValue = try XCTUnwrap(cryptomatorKeychainMock.setValueReceivedArguments?.value)
		XCTAssertEqual(lastUsedDate, try JSONDecoder().decode(Date.self, from: passedValue))
	}

	func testGetLastUsedDate() throws {
		let lastUsedDate = Date(timeIntervalSince1970: 0)
		let lastUsedDateJSON = try JSONEncoder().encode(lastUsedDate)
		cryptomatorKeychainMock.getAsDataReturnValue = lastUsedDateJSON

		let retrievedLastUsedDate = vaultAutoLockingManager.getLastUsedDate(forVaultUID: vaultUID)
		XCTAssertEqual(lastUsedDate, retrievedLastUsedDate)
		XCTAssertEqual(1, cryptomatorKeychainMock.getAsDataCallsCount)
		XCTAssertEqual(lastUsedDateKey, cryptomatorKeychainMock.getAsDataReceivedKey)
	}

	func testGetLastUsedDateNoEntry() throws {
		cryptomatorKeychainMock.getAsDataReturnValue = nil

		let retrievedLastUsedDate = vaultAutoLockingManager.getLastUsedDate(forVaultUID: vaultUID)
		XCTAssertNil(retrievedLastUsedDate)
		XCTAssertEqual(1, cryptomatorKeychainMock.getAsDataCallsCount)
		XCTAssertEqual(lastUsedDateKey, cryptomatorKeychainMock.getAsDataReceivedKey)
	}

	// MARK: Should Auto-Lock Vault

	func testShouldAutoLockVault() throws {
		cryptomatorKeychainMock.getAsDataClosure = { key in
			switch key {
			case self.autoLockKey:
				let keepUnlockedSetting = 60
				return try? JSONEncoder().encode(keepUnlockedSetting)
			case self.lastUsedDateKey:
				let lastUsedDate = Date().addingTimeInterval(-59)
				return try? JSONEncoder().encode(lastUsedDate)
			default:
				return nil
			}
		}
		XCTAssertFalse(vaultAutoLockingManager.shouldAutoLockVault(withVaultUID: vaultUID))
		XCTAssertEqual(2, cryptomatorKeychainMock.getAsDataCallsCount)
		XCTAssertEqual([autoLockKey, lastUsedDateKey], cryptomatorKeychainMock.getAsDataReceivedInvocations)
	}

	func testShouldAutoLockVaultNoLastUsedDateSet() throws {
		cryptomatorKeychainMock.getAsDataClosure = { key in
			switch key {
			case self.autoLockKey:
				let keepUnlockedSetting = KeepUnlockedSetting.oneMinute
				return try? JSONEncoder().encode(keepUnlockedSetting)
			case self.lastUsedDateKey:
				return nil
			default:
				return nil
			}
		}
		XCTAssert(vaultAutoLockingManager.shouldAutoLockVault(withVaultUID: vaultUID))
		XCTAssertEqual(2, cryptomatorKeychainMock.getAsDataCallsCount)
		XCTAssertEqual([autoLockKey, lastUsedDateKey], cryptomatorKeychainMock.getAsDataReceivedInvocations)
	}

	func testShouldAutoLockVaultLastUsedDateDistantPast() throws {
		cryptomatorKeychainMock.getAsDataClosure = { key in
			switch key {
			case self.autoLockKey:
				let keepUnlockedSetting = KeepUnlockedSetting.oneMinute
				return try? JSONEncoder().encode(keepUnlockedSetting)
			case self.lastUsedDateKey:
				let lastUsedDate = Date.distantPast
				return try? JSONEncoder().encode(lastUsedDate)
			default:
				return nil
			}
		}
		XCTAssert(vaultAutoLockingManager.shouldAutoLockVault(withVaultUID: vaultUID))
		XCTAssertEqual(2, cryptomatorKeychainMock.getAsDataCallsCount)
		XCTAssertEqual([autoLockKey, lastUsedDateKey], cryptomatorKeychainMock.getAsDataReceivedInvocations)
	}

	func testShouldAutoLockVaultLastUsedDateTooLate() throws {
		cryptomatorKeychainMock.getAsDataClosure = { key in
			switch key {
			case self.autoLockKey:
				let keepUnlockedSetting = KeepUnlockedSetting.oneMinute
				return try? JSONEncoder().encode(keepUnlockedSetting)
			case self.lastUsedDateKey:
				let lastUsedDate = Date().addingTimeInterval(-60)
				return try? JSONEncoder().encode(lastUsedDate)
			default:
				return nil
			}
		}
		XCTAssert(vaultAutoLockingManager.shouldAutoLockVault(withVaultUID: vaultUID))
		XCTAssertEqual(2, cryptomatorKeychainMock.getAsDataCallsCount)
		XCTAssertEqual([autoLockKey, lastUsedDateKey], cryptomatorKeychainMock.getAsDataReceivedInvocations)
	}

	func testShouldAutoLockVaultWithKeepUnlockedSettingOff() throws {
		cryptomatorKeychainMock.getAsDataClosure = { key in
			switch key {
			case self.autoLockKey:
				let keepUnlockedSetting = KeepUnlockedSetting.off
				return try? JSONEncoder().encode(keepUnlockedSetting)
			case self.lastUsedDateKey:
				return nil
			default:
				return nil
			}
		}
		XCTAssertFalse(vaultAutoLockingManager.shouldAutoLockVault(withVaultUID: vaultUID))
		XCTAssertEqual(1, cryptomatorKeychainMock.getAsDataCallsCount)
		XCTAssertEqual([autoLockKey], cryptomatorKeychainMock.getAsDataReceivedInvocations)
	}

	func testShouldAutoLockVaultWithKeepUnlockedSettingNever() throws {
		cryptomatorKeychainMock.getAsDataClosure = { key in
			switch key {
			case self.autoLockKey:
				let keepUnlockedSetting = KeepUnlockedSetting.never
				return try? JSONEncoder().encode(keepUnlockedSetting)
			case self.lastUsedDateKey:
				return nil
			default:
				return nil
			}
		}
		XCTAssertFalse(vaultAutoLockingManager.shouldAutoLockVault(withVaultUID: vaultUID))
		XCTAssertEqual(1, cryptomatorKeychainMock.getAsDataCallsCount)
		XCTAssertEqual([autoLockKey], cryptomatorKeychainMock.getAsDataReceivedInvocations)
	}

	// MARK: Should Auto-Unlock Vault

	func testShouldAutoUnlockVaultWithKeepUnlockedSettingOff() {
		cryptomatorKeychainMock.getAsDataClosure = { key in
			switch key {
			case self.autoLockKey:
				let keepUnlockedSetting = KeepUnlockedSetting.off
				return try? JSONEncoder().encode(keepUnlockedSetting)
			case self.lastUsedDateKey:
				return nil
			default:
				return nil
			}
		}
		XCTAssertFalse(vaultAutoLockingManager.shouldAutoUnlockVault(withVaultUID: vaultUID))
		XCTAssertEqual(1, cryptomatorKeychainMock.getAsDataCallsCount)
		XCTAssertEqual([autoLockKey], cryptomatorKeychainMock.getAsDataReceivedInvocations)
	}

	func testShouldAutoUnlockVaultWithKeepUnlockedSettingNever() {
		cryptomatorKeychainMock.getAsDataClosure = { key in
			switch key {
			case self.autoLockKey:
				let keepUnlockedSetting = KeepUnlockedSetting.never
				return try? JSONEncoder().encode(keepUnlockedSetting)
			case self.lastUsedDateKey:
				return nil
			default:
				return nil
			}
		}
		XCTAssert(vaultAutoLockingManager.shouldAutoUnlockVault(withVaultUID: vaultUID))
		XCTAssertEqual(1, cryptomatorKeychainMock.getAsDataCallsCount)
		XCTAssertEqual([autoLockKey], cryptomatorKeychainMock.getAsDataReceivedInvocations)
	}

	func testShouldAutoUnlockVaultWithShouldAutoLock() {
		cryptomatorKeychainMock.getAsDataClosure = { key in
			switch key {
			case self.autoLockKey:
				let keepUnlockedSetting = KeepUnlockedSetting.oneMinute
				return try? JSONEncoder().encode(keepUnlockedSetting)
			case self.lastUsedDateKey:
				return nil
			default:
				return nil
			}
		}
		let vaultAutoLockingManager = VaultAutoLockingManagerShouldAutoLockMocked(shouldAutoLockVault: true, keychain: cryptomatorKeychainMock)
		XCTAssertFalse(vaultAutoLockingManager.shouldAutoUnlockVault(withVaultUID: vaultUID))
		XCTAssertEqual(1, cryptomatorKeychainMock.getAsDataCallsCount)
		XCTAssertEqual([autoLockKey], cryptomatorKeychainMock.getAsDataReceivedInvocations)
	}

	func testShouldAutoUnlockVaultWithShouldNotAutoLock() {
		cryptomatorKeychainMock.getAsDataClosure = { key in
			switch key {
			case self.autoLockKey:
				let keepUnlockedSetting = KeepUnlockedSetting.oneMinute
				return try? JSONEncoder().encode(keepUnlockedSetting)
			case self.lastUsedDateKey:
				return nil
			default:
				return nil
			}
		}
		let vaultAutoLockingManager = VaultAutoLockingManagerShouldAutoLockMocked(shouldAutoLockVault: false, keychain: cryptomatorKeychainMock)
		XCTAssert(vaultAutoLockingManager.shouldAutoUnlockVault(withVaultUID: vaultUID))
		XCTAssertEqual(1, cryptomatorKeychainMock.getAsDataCallsCount)
		XCTAssertEqual([autoLockKey], cryptomatorKeychainMock.getAsDataReceivedInvocations)
	}
}

private class VaultAutoLockingManagerShouldAutoLockMocked: VaultAutoLockingManager {
	private let shouldAutoLockVaultReturnValue: Bool

	init(shouldAutoLockVault: Bool, keychain: CryptomatorKeychainType) {
		self.shouldAutoLockVaultReturnValue = shouldAutoLockVault
		super.init(keychain: keychain)
	}

	override func shouldAutoLockVault(withVaultUID vaultUID: String) -> Bool {
		return shouldAutoLockVaultReturnValue
	}
}
