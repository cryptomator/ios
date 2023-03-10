//
//  VaultKeepUnlockedManager.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 04.01.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import Foundation

public protocol VaultKeepUnlockedSettings {
	/**
	 Returns the keep unlocked duration for the passed `vaultUID`.

	 If no keep unlocked duration is set the `defaultKeepUnlockedDuration` will be returned.
	 */
	func getKeepUnlockedDuration(forVaultUID vaultUID: String) -> KeepUnlockedDuration
	func setKeepUnlockedDuration(_ duration: KeepUnlockedDuration, forVaultUID vaultUID: String) throws
	func removeKeepUnlockedDuration(forVaultUID vaultUID: String) throws

	func getLastUsedDate(forVaultUID vaultUID: String) -> Date?
	func setLastUsedDate(_ date: Date, forVaultUID vaultUID: String) throws
}

public extension VaultKeepUnlockedSettings {
	var defaultKeepUnlockedDuration: KeepUnlockedDuration {
		return .auto
	}
}

public protocol VaultKeepUnlockedHelper {
	/**
	 Returns if the vault should be automatically locked.

	 A vault should never be automatically locked  if the corresponding keep unlocked duration is  `KeepUnlockedDuration.auto` or `KeepUnlockedDuration.indefinite`.
	 The vault corresponding to the `vaultUID` should be locked if the last activity of the vault + the time interval of the corresponding Auto-Lock timeout `<=` the current date or if the vault was not yet used.
	 */
	func shouldAutoLockVault(withVaultUID vaultUID: String) -> Bool

	/**
	 Returns if the vault corresponding to the `vaultUID` should be automatically unlocked.

	 A vault should never be automatically unlocked if the corresponding keep unlocked duration is not set.
	 Otherwise a vault should be automatically unlocked if it is not supposed to be automatically locked.
	 */
	func shouldAutoUnlockVault(withVaultUID vaultUID: String) -> Bool
}

public class VaultKeepUnlockedManager: VaultKeepUnlockedHelper {
	public static let shared = VaultKeepUnlockedManager(keychain: CryptomatorKeychain.keepUnlocked)
	private let keychain: CryptomatorKeychainType

	init(keychain: CryptomatorKeychainType) {
		self.keychain = keychain
	}

	public func shouldAutoLockVault(withVaultUID vaultUID: String) -> Bool {
		let keepUnlockedDuration = getKeepUnlockedDuration(forVaultUID: vaultUID)
		guard let keepUnlockedDurationTimeInterval = keepUnlockedDuration.timeInterval else {
			return false
		}
		guard let lastUsedDate = getLastUsedDate(forVaultUID: vaultUID) else {
			return true
		}
		return lastUsedDate.addingTimeInterval(keepUnlockedDurationTimeInterval) <= Date()
	}

	public func shouldAutoUnlockVault(withVaultUID vaultUID: String) -> Bool {
		let keepUnlockedDuration = getKeepUnlockedDuration(forVaultUID: vaultUID)
		switch keepUnlockedDuration {
		case .auto:
			return false
		case .indefinite:
			return true
		case .fiveMinutes, .tenMinutes, .thirtyMinutes, .oneHour:
			return !shouldAutoLockVault(withVaultUID: vaultUID)
		}
	}
}

extension VaultKeepUnlockedManager: VaultKeepUnlockedSettings {
	public func getKeepUnlockedDuration(forVaultUID vaultUID: String) -> KeepUnlockedDuration {
		guard let data = keychain.getAsData(getKeepUnlockedDurationKey(forVaultUID: vaultUID)) else {
			return defaultKeepUnlockedDuration
		}
		let jsonDecoder = JSONDecoder()
		do {
			return try jsonDecoder.decode(KeepUnlockedDuration.self, from: data)
		} catch {
			return defaultKeepUnlockedDuration
		}
	}

	public func setKeepUnlockedDuration(_ duration: KeepUnlockedDuration, forVaultUID vaultUID: String) throws {
		let jsonEncoder = JSONEncoder()
		try keychain.set(getKeepUnlockedDurationKey(forVaultUID: vaultUID), value: jsonEncoder.encode(duration))
	}

	public func removeKeepUnlockedDuration(forVaultUID vaultUID: String) throws {
		do {
			try keychain.delete(getKeepUnlockedDurationKey(forVaultUID: vaultUID))
		} catch let CryptomatorKeychainError.unhandledError(statuscode) where statuscode == errSecItemNotFound {}
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
		try keychain.set(getLastUsedDateKey(forVaultUID: vaultUID), value: jsonEncoder.encode(date))
	}

	private func getKeepUnlockedDurationKey(forVaultUID vaultUID: String) -> String {
		return "\(vaultUID)-keepUnlockedDuration"
	}

	private func getLastUsedDateKey(forVaultUID vaultUID: String) -> String {
		return "\(vaultUID)-lastUsedDate"
	}
}

extension VaultKeepUnlockedManager: MasterkeyCacheHelper {
	func shouldCacheMasterkey(forVaultUID vaultUID: String) -> Bool {
		let keepUnlockedDuration = getKeepUnlockedDuration(forVaultUID: vaultUID)
		switch keepUnlockedDuration {
		case .auto:
			return false
		case .indefinite, .fiveMinutes, .tenMinutes, .thirtyMinutes, .oneHour:
			return true
		}
	}
}
