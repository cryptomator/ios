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
	 Returns the Auto-Lock timeout for the passed `vaultUID`.

	 If no Auto-Lock timeout is set the `defaultKeepUnlockedSetting` will be returned.
	 */
	func getKeepUnlockedSetting(forVaultUID vaultUID: String) -> KeepUnlockedSetting
	func setKeepUnlockedSetting(_ timeout: KeepUnlockedSetting, forVaultUID vaultUID: String) throws

	func getLastUsedDate(forVaultUID vaultUID: String) -> Date?
	func setLastUsedDate(_ date: Date, forVaultUID vaultUID: String) throws
}

extension VaultKeepUnlockedSettings {
	var defaultKeepUnlockedSetting: KeepUnlockedSetting {
		return .fiveMinutes
	}
}

public protocol VaultKeepUnlockedHelper {
	/**
	 Returns if the vault should be automatically locked.

	 A vault should never be automatically locked  if the corresponding Auto-Lock timeout is `KeepUnlockedSetting.off` or `KeepUnlockedSetting.never`.
	 The vault corresponding to the `vaultUID` should be locked if the last activity of the vault + the time interval of the corresponding Auto-Lock timeout `<=` the current date or if the vault was not yet used.
	 */
	func shouldAutoLockVault(withVaultUID vaultUID: String) -> Bool

	/**
	 Returns if the vault corresponding to the `vaultUID` should be automatically unlocked.

	 A vault should never be automatically unlocked if the corresponding Auto-Lock timeout is `KeepUnlockedSetting.off`.
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
		let keepUnlockedSetting = getKeepUnlockedSetting(forVaultUID: vaultUID)
		guard let keepUnlockedSettingTimeInterval = keepUnlockedSetting.timeInterval else {
			return false
		}
		guard let lastUsedDate = getLastUsedDate(forVaultUID: vaultUID) else {
			return true
		}
		return lastUsedDate.addingTimeInterval(keepUnlockedSettingTimeInterval) <= Date()
	}

	public func shouldAutoUnlockVault(withVaultUID vaultUID: String) -> Bool {
		let keepUnlockedSetting = getKeepUnlockedSetting(forVaultUID: vaultUID)
		switch keepUnlockedSetting {
		case .off:
			return false
		case .never:
			return true
		case .oneMinute, .twoMinutes, .fiveMinutes, .tenMinutes, .fifteenMinutes, .thirtyMinutes, .oneHour:
			return !shouldAutoLockVault(withVaultUID: vaultUID)
		}
	}
}

extension VaultKeepUnlockedManager: VaultKeepUnlockedSettings {
	public func getKeepUnlockedSetting(forVaultUID vaultUID: String) -> KeepUnlockedSetting {
		guard let data = keychain.getAsData(getKeepUnlockedSettingKey(forVaultUID: vaultUID)) else {
			return defaultKeepUnlockedSetting
		}
		let jsonDecoder = JSONDecoder()
		do {
			return try jsonDecoder.decode(KeepUnlockedSetting.self, from: data)
		} catch {
			return defaultKeepUnlockedSetting
		}
	}

	public func setKeepUnlockedSetting(_ timeout: KeepUnlockedSetting, forVaultUID vaultUID: String) throws {
		let jsonEncoder = JSONEncoder()
		try keychain.set(getKeepUnlockedSettingKey(forVaultUID: vaultUID), value: try jsonEncoder.encode(timeout))
	}

	public func removeKeepUnlockedSetting(forVaultUID vaultUID: String) throws {
		try keychain.delete(getKeepUnlockedSettingKey(forVaultUID: vaultUID))
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

	private func getKeepUnlockedSettingKey(forVaultUID vaultUID: String) -> String {
		return "\(vaultUID)-keepUnlockedSetting"
	}

	private func getLastUsedDateKey(forVaultUID vaultUID: String) -> String {
		return "\(vaultUID)-lastUsedDate"
	}
}

extension VaultKeepUnlockedManager: MasterkeyCacheHelper {
	func shouldCacheMasterkey(forVaultUID vaultUID: String) -> Bool {
		let keepUnlockedSetting = getKeepUnlockedSetting(forVaultUID: vaultUID)
		switch keepUnlockedSetting {
		case .off:
			return false
		case .never, .oneMinute, .twoMinutes, .fiveMinutes, .tenMinutes, .fifteenMinutes, .thirtyMinutes, .oneHour:
			return true
		}
	}
}
