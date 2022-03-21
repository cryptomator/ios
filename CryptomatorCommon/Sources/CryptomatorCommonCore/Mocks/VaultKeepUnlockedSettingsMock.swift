//
//  VaultKeepUnlockedSettingsMock.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 04.01.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

#if DEBUG
import Foundation

// swiftlint:disable all
final class VaultKeepUnlockedSettingsMock: VaultKeepUnlockedSettings {
	// MARK: - getKeepUnlockedDuration

	var getKeepUnlockedDurationForVaultUIDCallsCount = 0
	var getKeepUnlockedDurationForVaultUIDCalled: Bool {
		getKeepUnlockedDurationForVaultUIDCallsCount > 0
	}

	var getKeepUnlockedDurationForVaultUIDReceivedVaultUID: String?
	var getKeepUnlockedDurationForVaultUIDReceivedInvocations: [String] = []
	var getKeepUnlockedDurationForVaultUIDReturnValue: KeepUnlockedDuration!
	var getKeepUnlockedDurationForVaultUIDClosure: ((String) -> KeepUnlockedDuration)?

	func getKeepUnlockedDuration(forVaultUID vaultUID: String) -> KeepUnlockedDuration {
		getKeepUnlockedDurationForVaultUIDCallsCount += 1
		getKeepUnlockedDurationForVaultUIDReceivedVaultUID = vaultUID
		getKeepUnlockedDurationForVaultUIDReceivedInvocations.append(vaultUID)
		return getKeepUnlockedDurationForVaultUIDClosure.map({ $0(vaultUID) }) ?? getKeepUnlockedDurationForVaultUIDReturnValue
	}

	// MARK: - setKeepUnlockedDuration

	var setKeepUnlockedDurationForVaultUIDThrowableError: Error?
	var setKeepUnlockedDurationForVaultUIDCallsCount = 0
	var setKeepUnlockedDurationForVaultUIDCalled: Bool {
		setKeepUnlockedDurationForVaultUIDCallsCount > 0
	}

	var setKeepUnlockedDurationForVaultUIDReceivedArguments: (duration: KeepUnlockedDuration, vaultUID: String)?
	var setKeepUnlockedDurationForVaultUIDReceivedInvocations: [(duration: KeepUnlockedDuration, vaultUID: String)] = []
	var setKeepUnlockedDurationForVaultUIDClosure: ((KeepUnlockedDuration, String) throws -> Void)?

	func setKeepUnlockedDuration(_ duration: KeepUnlockedDuration, forVaultUID vaultUID: String) throws {
		if let error = setKeepUnlockedDurationForVaultUIDThrowableError {
			throw error
		}
		setKeepUnlockedDurationForVaultUIDCallsCount += 1
		setKeepUnlockedDurationForVaultUIDReceivedArguments = (duration: duration, vaultUID: vaultUID)
		setKeepUnlockedDurationForVaultUIDReceivedInvocations.append((duration: duration, vaultUID: vaultUID))
		try setKeepUnlockedDurationForVaultUIDClosure?(duration, vaultUID)
	}

	// MARK: - removeKeepUnlockedDuration

	var removeKeepUnlockedDurationForVaultUIDThrowableError: Error?
	var removeKeepUnlockedDurationForVaultUIDCallsCount = 0
	var removeKeepUnlockedDurationForVaultUIDCalled: Bool {
		removeKeepUnlockedDurationForVaultUIDCallsCount > 0
	}

	var removeKeepUnlockedDurationForVaultUIDReceivedVaultUID: String?
	var removeKeepUnlockedDurationForVaultUIDReceivedInvocations: [String] = []
	var removeKeepUnlockedDurationForVaultUIDClosure: ((String) throws -> Void)?

	func removeKeepUnlockedDuration(forVaultUID vaultUID: String) throws {
		if let error = removeKeepUnlockedDurationForVaultUIDThrowableError {
			throw error
		}
		removeKeepUnlockedDurationForVaultUIDCallsCount += 1
		removeKeepUnlockedDurationForVaultUIDReceivedVaultUID = vaultUID
		removeKeepUnlockedDurationForVaultUIDReceivedInvocations.append(vaultUID)
		try removeKeepUnlockedDurationForVaultUIDClosure?(vaultUID)
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
#endif
