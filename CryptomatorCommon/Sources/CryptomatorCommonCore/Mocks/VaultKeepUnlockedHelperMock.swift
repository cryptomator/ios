//
//  VaultKeepUnlockedHelperMock.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 12.01.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

#if DEBUG
import Foundation

// swiftlint:disable all
final class VaultKeepUnlockedHelperMock: VaultKeepUnlockedHelper {
	// MARK: - shouldAutoLockVault

	var shouldAutoLockVaultWithVaultUIDCallsCount = 0
	var shouldAutoLockVaultWithVaultUIDCalled: Bool {
		shouldAutoLockVaultWithVaultUIDCallsCount > 0
	}

	var shouldAutoLockVaultWithVaultUIDReceivedVaultUID: String?
	var shouldAutoLockVaultWithVaultUIDReceivedInvocations: [String] = []
	var shouldAutoLockVaultWithVaultUIDReturnValue: Bool!
	var shouldAutoLockVaultWithVaultUIDClosure: ((String) -> Bool)?

	func shouldAutoLockVault(withVaultUID vaultUID: String) -> Bool {
		shouldAutoLockVaultWithVaultUIDCallsCount += 1
		shouldAutoLockVaultWithVaultUIDReceivedVaultUID = vaultUID
		shouldAutoLockVaultWithVaultUIDReceivedInvocations.append(vaultUID)
		return shouldAutoLockVaultWithVaultUIDClosure.map({ $0(vaultUID) }) ?? shouldAutoLockVaultWithVaultUIDReturnValue
	}

	// MARK: - shouldAutoUnlockVault

	var shouldAutoUnlockVaultWithVaultUIDCallsCount = 0
	var shouldAutoUnlockVaultWithVaultUIDCalled: Bool {
		shouldAutoUnlockVaultWithVaultUIDCallsCount > 0
	}

	var shouldAutoUnlockVaultWithVaultUIDReceivedVaultUID: String?
	var shouldAutoUnlockVaultWithVaultUIDReceivedInvocations: [String] = []
	var shouldAutoUnlockVaultWithVaultUIDReturnValue: Bool!
	var shouldAutoUnlockVaultWithVaultUIDClosure: ((String) -> Bool)?

	func shouldAutoUnlockVault(withVaultUID vaultUID: String) -> Bool {
		shouldAutoUnlockVaultWithVaultUIDCallsCount += 1
		shouldAutoUnlockVaultWithVaultUIDReceivedVaultUID = vaultUID
		shouldAutoUnlockVaultWithVaultUIDReceivedInvocations.append(vaultUID)
		return shouldAutoUnlockVaultWithVaultUIDClosure.map({ $0(vaultUID) }) ?? shouldAutoUnlockVaultWithVaultUIDReturnValue
	}
}

// swiftlint:enable all
#endif
