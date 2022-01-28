//
//  VaultCacheMock.swift
//  CryptomatorCommonCoreTests
//
//  Created by Philipp Schmid on 28.01.22.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation
import Promises
@testable import CryptomatorCommonCore

// swiftlint:disable all
final class VaultCacheMock: VaultCache {
	// MARK: - cache

	var cacheThrowableError: Error?
	var cacheCallsCount = 0
	var cacheCalled: Bool {
		cacheCallsCount > 0
	}

	var cacheReceivedEntry: CachedVault?
	var cacheReceivedInvocations: [CachedVault] = []
	var cacheClosure: ((CachedVault) throws -> Void)?

	func cache(_ entry: CachedVault) throws {
		if let error = cacheThrowableError {
			throw error
		}
		cacheCallsCount += 1
		cacheReceivedEntry = entry
		cacheReceivedInvocations.append(entry)
		try cacheClosure?(entry)
	}

	// MARK: - getCachedVault

	var getCachedVaultWithVaultUIDThrowableError: Error?
	var getCachedVaultWithVaultUIDCallsCount = 0
	var getCachedVaultWithVaultUIDCalled: Bool {
		getCachedVaultWithVaultUIDCallsCount > 0
	}

	var getCachedVaultWithVaultUIDReceivedVaultUID: String?
	var getCachedVaultWithVaultUIDReceivedInvocations: [String] = []
	var getCachedVaultWithVaultUIDReturnValue: CachedVault!
	var getCachedVaultWithVaultUIDClosure: ((String) throws -> CachedVault)?

	func getCachedVault(withVaultUID vaultUID: String) throws -> CachedVault {
		if let error = getCachedVaultWithVaultUIDThrowableError {
			throw error
		}
		getCachedVaultWithVaultUIDCallsCount += 1
		getCachedVaultWithVaultUIDReceivedVaultUID = vaultUID
		getCachedVaultWithVaultUIDReceivedInvocations.append(vaultUID)
		return try getCachedVaultWithVaultUIDClosure.map({ try $0(vaultUID) }) ?? getCachedVaultWithVaultUIDReturnValue
	}

	// MARK: - invalidate

	var invalidateVaultUIDThrowableError: Error?
	var invalidateVaultUIDCallsCount = 0
	var invalidateVaultUIDCalled: Bool {
		invalidateVaultUIDCallsCount > 0
	}

	var invalidateVaultUIDReceivedVaultUID: String?
	var invalidateVaultUIDReceivedInvocations: [String] = []
	var invalidateVaultUIDClosure: ((String) throws -> Void)?

	func invalidate(vaultUID: String) throws {
		if let error = invalidateVaultUIDThrowableError {
			throw error
		}
		invalidateVaultUIDCallsCount += 1
		invalidateVaultUIDReceivedVaultUID = vaultUID
		invalidateVaultUIDReceivedInvocations.append(vaultUID)
		try invalidateVaultUIDClosure?(vaultUID)
	}

	// MARK: - refreshVaultCache

	var refreshVaultCacheForWithThrowableError: Error?
	var refreshVaultCacheForWithCallsCount = 0
	var refreshVaultCacheForWithCalled: Bool {
		refreshVaultCacheForWithCallsCount > 0
	}

	var refreshVaultCacheForWithReceivedArguments: (vault: VaultAccount, provider: CloudProvider)?
	var refreshVaultCacheForWithReceivedInvocations: [(vault: VaultAccount, provider: CloudProvider)] = []
	var refreshVaultCacheForWithReturnValue: Promise<Void> = Promise(())
	var refreshVaultCacheForWithClosure: ((VaultAccount, CloudProvider) -> Promise<Void>)?

	func refreshVaultCache(for vault: VaultAccount, with provider: CloudProvider) -> Promise<Void> {
		if let error = refreshVaultCacheForWithThrowableError {
			return Promise(error)
		}
		refreshVaultCacheForWithCallsCount += 1
		refreshVaultCacheForWithReceivedArguments = (vault: vault, provider: provider)
		refreshVaultCacheForWithReceivedInvocations.append((vault: vault, provider: provider))
		return refreshVaultCacheForWithClosure.map({ $0(vault, provider) }) ?? refreshVaultCacheForWithReturnValue
	}
}

// swiftlint:enable all
