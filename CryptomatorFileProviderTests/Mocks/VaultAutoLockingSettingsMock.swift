//
//  VaultAutoLockingSettingsMock.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 12.01.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import Foundation

// swiftlint:disable all
final class VaultAutoLockingSettingsMock: VaultAutoLockingSettings {
	// MARK: - getKeepUnlockedSetting

	var getKeepUnlockedSettingForVaultUIDCallsCount = 0
	var getKeepUnlockedSettingForVaultUIDCalled: Bool {
		getKeepUnlockedSettingForVaultUIDCallsCount > 0
	}

	var getKeepUnlockedSettingForVaultUIDReceivedVaultUID: String?
	var getKeepUnlockedSettingForVaultUIDReceivedInvocations: [String] = []
	var getKeepUnlockedSettingForVaultUIDReturnValue: KeepUnlockedSetting!
	var getKeepUnlockedSettingForVaultUIDClosure: ((String) -> KeepUnlockedSetting)?

	func getKeepUnlockedSetting(forVaultUID vaultUID: String) -> KeepUnlockedSetting {
		getKeepUnlockedSettingForVaultUIDCallsCount += 1
		getKeepUnlockedSettingForVaultUIDReceivedVaultUID = vaultUID
		getKeepUnlockedSettingForVaultUIDReceivedInvocations.append(vaultUID)
		return getKeepUnlockedSettingForVaultUIDClosure.map({ $0(vaultUID) }) ?? getKeepUnlockedSettingForVaultUIDReturnValue
	}

	// MARK: - setKeepUnlockedSetting

	var setKeepUnlockedSettingForVaultUIDThrowableError: Error?
	var setKeepUnlockedSettingForVaultUIDCallsCount = 0
	var setKeepUnlockedSettingForVaultUIDCalled: Bool {
		setKeepUnlockedSettingForVaultUIDCallsCount > 0
	}

	var setKeepUnlockedSettingForVaultUIDReceivedArguments: (timeout: KeepUnlockedSetting, vaultUID: String)?
	var setKeepUnlockedSettingForVaultUIDReceivedInvocations: [(timeout: KeepUnlockedSetting, vaultUID: String)] = []
	var setKeepUnlockedSettingForVaultUIDClosure: ((KeepUnlockedSetting, String) throws -> Void)?

	func setKeepUnlockedSetting(_ timeout: KeepUnlockedSetting, forVaultUID vaultUID: String) throws {
		if let error = setKeepUnlockedSettingForVaultUIDThrowableError {
			throw error
		}
		setKeepUnlockedSettingForVaultUIDCallsCount += 1
		setKeepUnlockedSettingForVaultUIDReceivedArguments = (timeout: timeout, vaultUID: vaultUID)
		setKeepUnlockedSettingForVaultUIDReceivedInvocations.append((timeout: timeout, vaultUID: vaultUID))
		try setKeepUnlockedSettingForVaultUIDClosure?(timeout, vaultUID)
	}

	// MARK: - getLastUsedDate

	var getLastUsedDateForVaultUIDCallsCount = 0
	var getLastUsedDateForVaultUIDCalled: Bool {
		getLastUsedDateForVaultUIDCallsCount > 0
	}

	var getLastUsedDateForVaultUIDReceivedVaultUID: String?
	var getLastUsedDateForVaultUIDReceivedInvocations: [String] = []
	var getLastUsedDateForVaultUIDReturnValue: Date?
	var getLastUsedDateForVaultUIDClosure: ((String) -> Date?)?

	func getLastUsedDate(forVaultUID vaultUID: String) -> Date? {
		getLastUsedDateForVaultUIDCallsCount += 1
		getLastUsedDateForVaultUIDReceivedVaultUID = vaultUID
		getLastUsedDateForVaultUIDReceivedInvocations.append(vaultUID)
		return getLastUsedDateForVaultUIDClosure.map({ $0(vaultUID) }) ?? getLastUsedDateForVaultUIDReturnValue
	}

	// MARK: - setLastUsedDate

	var setLastUsedDateForVaultUIDThrowableError: Error?
	var setLastUsedDateForVaultUIDCallsCount = 0
	var setLastUsedDateForVaultUIDCalled: Bool {
		setLastUsedDateForVaultUIDCallsCount > 0
	}

	var setLastUsedDateForVaultUIDReceivedArguments: (date: Date, vaultUID: String)?
	var setLastUsedDateForVaultUIDReceivedInvocations: [(date: Date, vaultUID: String)] = []
	var setLastUsedDateForVaultUIDClosure: ((Date, String) throws -> Void)?

	func setLastUsedDate(_ date: Date, forVaultUID vaultUID: String) throws {
		if let error = setLastUsedDateForVaultUIDThrowableError {
			throw error
		}
		setLastUsedDateForVaultUIDCallsCount += 1
		setLastUsedDateForVaultUIDReceivedArguments = (date: date, vaultUID: vaultUID)
		setLastUsedDateForVaultUIDReceivedInvocations.append((date: date, vaultUID: vaultUID))
		try setLastUsedDateForVaultUIDClosure?(date, vaultUID)
	}
}

// swiftlint:enable all
