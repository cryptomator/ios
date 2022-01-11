//
//  VaultAutoLockingManager.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 04.01.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import Foundation

public protocol VaultAutoLockingSettings {
	/**
	 Returns the Auto-Lock timeout for the passed `vaultUID`.

	 If no Auto-Lock timeout is set the `defaultAutoLockTimeout` will be returned.
	 */
	func getAutoLockTimeout(forVaultUID vaultUID: String) -> AutoLockTimeout
	func setAutoLockTimeout(_ timeout: AutoLockTimeout, forVaultUID vaultUID: String) throws

	func getLastUsedDate(forVaultUID vaultUID: String) -> Date?
	func setLastUsedDate(_ date: Date, forVaultUID vaultUID: String) throws
}

extension VaultAutoLockingSettings {
	var defaultAutoLockTimeout: AutoLockTimeout {
		return .fiveMinutes
	}
}

public protocol VaultAutoLockingHelper {
	/**
	 Returns if the vault should be automatically locked.

	 A vault should never be automatically locked  if the corresponding Auto-Lock timeout is `AutoLockTimeout.off` or `AutoLockTimeout.never`.
	 The vault corresponding to the `vaultUID` should be locked if the last activity of the vault + the time interval of the corresponding Auto-Lock timeout `<=` the current date or if the vault was not yet used.
	 */
	func shouldAutoLockVault(withVaultUID vaultUID: String) -> Bool

	/**
	 Returns if the vault corresponding to the `vaultUID` should be automatically unlocked.

	 A vault should never be automatically unlocked if the corresponding Auto-Lock timeout is `AutoLockTimeout.off`.
	 Otherwise a vault should be automatically unlocked if it is not supposed to be automatically locked.
	 */
	func shouldAutoUnlockVault(withVaultUID vaultUID: String) -> Bool
}

public class VaultAutoLockingManager: VaultAutoLockingHelper {
	public static let shared = VaultAutoLockingManager(keychain: CryptomatorKeychain.autoLock)
	private let keychain: CryptomatorKeychainType

	init(keychain: CryptomatorKeychainType) {
		self.keychain = keychain
	}

	public func shouldAutoLockVault(withVaultUID vaultUID: String) -> Bool {
		let autoLockTimeout = getAutoLockTimeout(forVaultUID: vaultUID)
		guard let autoLockTimeoutTimeInterval = autoLockTimeout.timeInterval else {
			return false
		}
		guard let lastUsedDate = getLastUsedDate(forVaultUID: vaultUID) else {
			return true
		}
		return lastUsedDate.addingTimeInterval(autoLockTimeoutTimeInterval) <= Date()
	}

	public func shouldAutoUnlockVault(withVaultUID vaultUID: String) -> Bool {
		let autoLockTimeout = getAutoLockTimeout(forVaultUID: vaultUID)
		switch autoLockTimeout {
		case .off:
			return false
		case .never:
			return true
		case .oneMinute, .twoMinutes, .fiveMinutes, .tenMinutes, .fifteenMinutes, .thirtyMinutes, .oneHour:
			return !shouldAutoLockVault(withVaultUID: vaultUID)
		}
	}
}

extension VaultAutoLockingManager: VaultAutoLockingSettings {
	public func getAutoLockTimeout(forVaultUID vaultUID: String) -> AutoLockTimeout {
		guard let data = keychain.getAsData(getAutoLockKey(forVaultUID: vaultUID)) else {
			return defaultAutoLockTimeout
		}
		let jsonDecoder = JSONDecoder()
		do {
			return try jsonDecoder.decode(AutoLockTimeout.self, from: data)
		} catch {
			return defaultAutoLockTimeout
		}
	}

	public func setAutoLockTimeout(_ timeout: AutoLockTimeout, forVaultUID vaultUID: String) throws {
		let jsonEncoder = JSONEncoder()
		try keychain.set(getAutoLockKey(forVaultUID: vaultUID), value: try jsonEncoder.encode(timeout))
	}

	public func removeAutoLockTimeout(forVaultUID vaultUID: String) throws {
		try keychain.delete(getAutoLockKey(forVaultUID: vaultUID))
	}

	public func getLastUsedDate(forVaultUID vaultUID: String) -> Date? {
		guard let data = keychain.getAsData(getLastUsedDateKey(forVaultUID: vaultUID)) else {
			return nil
		}
		let jsonDecoder = JSONDecoder()
		return try? jsonDecoder.decode(Date.self, from: data)
	}

	public func setLastUsedDate(_ date: Date, forVaultUID vaultUID: String) throws {
		let jsonEncoder = JSONEncoder()
		try keychain.set(getLastUsedDateKey(forVaultUID: vaultUID), value: try jsonEncoder.encode(date))
	}

	private func getAutoLockKey(forVaultUID vaultUID: String) -> String {
		return "\(vaultUID)-autoLockDuration"
	}

	private func getLastUsedDateKey(forVaultUID vaultUID: String) -> String {
		return "\(vaultUID)-lastUsedDate"
	}
}
