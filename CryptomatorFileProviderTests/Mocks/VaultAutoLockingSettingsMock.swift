//
//  VaultAutoLockingSettingsMock.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 12.01.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import Foundation

final class VaultAutoLockingSettingsMock: VaultAutoLockingSettings {
	// MARK: - getAutoLockTimeout

	var getAutoLockTimeoutForVaultUIDCallsCount = 0
	var getAutoLockTimeoutForVaultUIDCalled: Bool {
		getAutoLockTimeoutForVaultUIDCallsCount > 0
	}

	var getAutoLockTimeoutForVaultUIDReceivedVaultUID: String?
	var getAutoLockTimeoutForVaultUIDReceivedInvocations: [String] = []
	var getAutoLockTimeoutForVaultUIDReturnValue: AutoLockTimeout!
	var getAutoLockTimeoutForVaultUIDClosure: ((String) -> AutoLockTimeout)?

	func getAutoLockTimeout(forVaultUID vaultUID: String) -> AutoLockTimeout {
		getAutoLockTimeoutForVaultUIDCallsCount += 1
		getAutoLockTimeoutForVaultUIDReceivedVaultUID = vaultUID
		getAutoLockTimeoutForVaultUIDReceivedInvocations.append(vaultUID)
		return getAutoLockTimeoutForVaultUIDClosure.map({ $0(vaultUID) }) ?? getAutoLockTimeoutForVaultUIDReturnValue
	}

	// MARK: - setAutoLockTimeout

	var setAutoLockTimeoutForVaultUIDThrowableError: Error?
	var setAutoLockTimeoutForVaultUIDCallsCount = 0
	var setAutoLockTimeoutForVaultUIDCalled: Bool {
		setAutoLockTimeoutForVaultUIDCallsCount > 0
	}

	var setAutoLockTimeoutForVaultUIDReceivedArguments: (timeout: AutoLockTimeout, vaultUID: String)?
	var setAutoLockTimeoutForVaultUIDReceivedInvocations: [(timeout: AutoLockTimeout, vaultUID: String)] = []
	var setAutoLockTimeoutForVaultUIDClosure: ((AutoLockTimeout, String) throws -> Void)?

	func setAutoLockTimeout(_ timeout: AutoLockTimeout, forVaultUID vaultUID: String) throws {
		if let error = setAutoLockTimeoutForVaultUIDThrowableError {
			throw error
		}
		setAutoLockTimeoutForVaultUIDCallsCount += 1
		setAutoLockTimeoutForVaultUIDReceivedArguments = (timeout: timeout, vaultUID: vaultUID)
		setAutoLockTimeoutForVaultUIDReceivedInvocations.append((timeout: timeout, vaultUID: vaultUID))
		try setAutoLockTimeoutForVaultUIDClosure?(timeout, vaultUID)
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
