//
//  MasterkeyCacheManagerMock.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 11.01.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

#if DEBUG
import CryptomatorCryptoLib
import Foundation

// swiftlint:disable all
final class MasterkeyCacheManagerMock: MasterkeyCacheManager {
	// MARK: - cacheMasterkey

	var cacheMasterkeyForVaultUIDThrowableError: Error?
	var cacheMasterkeyForVaultUIDCallsCount = 0
	var cacheMasterkeyForVaultUIDCalled: Bool {
		cacheMasterkeyForVaultUIDCallsCount > 0
	}

	var cacheMasterkeyForVaultUIDReceivedArguments: (masterkey: Masterkey, vaultUID: String)?
	var cacheMasterkeyForVaultUIDReceivedInvocations: [(masterkey: Masterkey, vaultUID: String)] = []
	var cacheMasterkeyForVaultUIDClosure: ((Masterkey, String) throws -> Void)?

	func cacheMasterkey(_ masterkey: Masterkey, forVaultUID vaultUID: String) throws {
		if let error = cacheMasterkeyForVaultUIDThrowableError {
			throw error
		}
		cacheMasterkeyForVaultUIDCallsCount += 1
		cacheMasterkeyForVaultUIDReceivedArguments = (masterkey: masterkey, vaultUID: vaultUID)
		cacheMasterkeyForVaultUIDReceivedInvocations.append((masterkey: masterkey, vaultUID: vaultUID))
		try cacheMasterkeyForVaultUIDClosure?(masterkey, vaultUID)
	}

	// MARK: - getMasterkey

	var getMasterkeyForVaultUIDThrowableError: Error?
	var getMasterkeyForVaultUIDCallsCount = 0
	var getMasterkeyForVaultUIDCalled: Bool {
		getMasterkeyForVaultUIDCallsCount > 0
	}

	var getMasterkeyForVaultUIDReceivedVaultUID: String?
	var getMasterkeyForVaultUIDReceivedInvocations: [String] = []
	var getMasterkeyForVaultUIDReturnValue: Masterkey?
	var getMasterkeyForVaultUIDClosure: ((String) throws -> Masterkey?)?

	func getMasterkey(forVaultUID vaultUID: String) throws -> Masterkey? {
		if let error = getMasterkeyForVaultUIDThrowableError {
			throw error
		}
		getMasterkeyForVaultUIDCallsCount += 1
		getMasterkeyForVaultUIDReceivedVaultUID = vaultUID
		getMasterkeyForVaultUIDReceivedInvocations.append(vaultUID)
		return try getMasterkeyForVaultUIDClosure.map({ try $0(vaultUID) }) ?? getMasterkeyForVaultUIDReturnValue
	}

	// MARK: - removeCachedMasterkey

	var removeCachedMasterkeyForVaultUIDThrowableError: Error?
	var removeCachedMasterkeyForVaultUIDCallsCount = 0
	var removeCachedMasterkeyForVaultUIDCalled: Bool {
		removeCachedMasterkeyForVaultUIDCallsCount > 0
	}

	var removeCachedMasterkeyForVaultUIDReceivedVaultUID: String?
	var removeCachedMasterkeyForVaultUIDReceivedInvocations: [String] = []
	var removeCachedMasterkeyForVaultUIDClosure: ((String) throws -> Void)?

	func removeCachedMasterkey(forVaultUID vaultUID: String) throws {
		if let error = removeCachedMasterkeyForVaultUIDThrowableError {
			throw error
		}
		removeCachedMasterkeyForVaultUIDCallsCount += 1
		removeCachedMasterkeyForVaultUIDReceivedVaultUID = vaultUID
		removeCachedMasterkeyForVaultUIDReceivedInvocations.append(vaultUID)
		try removeCachedMasterkeyForVaultUIDClosure?(vaultUID)
	}
}

// swiftlint:enable all
#endif
