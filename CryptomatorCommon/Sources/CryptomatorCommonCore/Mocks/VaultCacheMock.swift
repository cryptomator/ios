//
//  VaultCacheMock.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 28.01.22.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

#if DEBUG
import CryptomatorCloudAccessCore
import Foundation

// swiftlint:disable all

/// @unchecked Sendable: test double, never touched concurrently
final class VaultCacheMock: VaultCache, @unchecked Sendable {
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

	// MARK: - refreshVaultCache

	var refreshVaultCacheForWithThrowableError: Error?
	var refreshVaultCacheForWithCallsCount = 0
	var refreshVaultCacheForWithCalled: Bool {
		refreshVaultCacheForWithCallsCount > 0
	}

	var refreshVaultCacheForWithReceivedArguments: (vault: VaultAccount, provider: CloudProvider)?
	var refreshVaultCacheForWithReceivedInvocations: [(vault: VaultAccount, provider: CloudProvider)] = []
	var refreshVaultCacheForWithClosure: ((VaultAccount, CloudProvider) async throws -> Void)?

	func refreshVaultCache(for vault: VaultAccount, with provider: CloudProvider) async throws {
		if let error = refreshVaultCacheForWithThrowableError {
			throw error
		}
		refreshVaultCacheForWithCallsCount += 1
		refreshVaultCacheForWithReceivedArguments = (vault: vault, provider: provider)
		refreshVaultCacheForWithReceivedInvocations.append((vault: vault, provider: provider))
		try await refreshVaultCacheForWithClosure?(vault, provider)
	}

	// MARK: - setMasterkeyFileData

	var setMasterkeyFileDataForVaultUIDLastModifiedDateThrowableError: Error?
	var setMasterkeyFileDataForVaultUIDLastModifiedDateCallsCount = 0
	var setMasterkeyFileDataForVaultUIDLastModifiedDateCalled: Bool {
		setMasterkeyFileDataForVaultUIDLastModifiedDateCallsCount > 0
	}

	var setMasterkeyFileDataForVaultUIDLastModifiedDateReceivedArguments: (data: Data, vaultUID: String, lastModifiedDate: Date?)?
	var setMasterkeyFileDataForVaultUIDLastModifiedDateReceivedInvocations: [(data: Data, vaultUID: String, lastModifiedDate: Date?)] = []
	var setMasterkeyFileDataForVaultUIDLastModifiedDateClosure: ((Data, String, Date?) throws -> Void)?

	func setMasterkeyFileData(_ data: Data, forVaultUID vaultUID: String, lastModifiedDate: Date?) throws {
		if let error = setMasterkeyFileDataForVaultUIDLastModifiedDateThrowableError {
			throw error
		}
		setMasterkeyFileDataForVaultUIDLastModifiedDateCallsCount += 1
		setMasterkeyFileDataForVaultUIDLastModifiedDateReceivedArguments = (data: data, vaultUID: vaultUID, lastModifiedDate: lastModifiedDate)
		setMasterkeyFileDataForVaultUIDLastModifiedDateReceivedInvocations.append((data: data, vaultUID: vaultUID, lastModifiedDate: lastModifiedDate))
		try setMasterkeyFileDataForVaultUIDLastModifiedDateClosure?(data, vaultUID, lastModifiedDate)
	}
}

// swiftlint:enable all
#endif
