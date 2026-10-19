//
//  UnlockVaultViewModelTests.swift
//  CryptomatorTests
//
//  Created by Tobias Hagemann on 21.04.26.
//  Copyright © 2026 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCryptoLib
import Dependencies
import FileProvider
import XCTest
@testable import CryptomatorCommonCore

@MainActor
class UnlockVaultViewModelTests: XCTestCase {
	private let vaultUID = "UnlockTestVault"
	private let passphrase = "testPassword"
	private var domain: NSFileProviderDomain!
	private var vaultAccount: VaultAccount!
	private var masterkeyFileData: Data!

	private var vaultCacheMock: CryptomatorCommonCore.VaultCacheMock!
	private var passwordManagerMock: CryptomatorCommonCore.VaultPasswordManagerMock!
	private var providerManagerMock: CloudProviderManagerStub!
	private var vaultAccountManagerMock: VaultAccountManagerStub!
	private var fileProviderConnectorMock: FileProviderConnectorMock!
	private var vaultUnlockingMock: VaultUnlockingMock!

	override func setUp() async throws {
		try await super.setUp()
		domain = NSFileProviderDomain(identifier: NSFileProviderDomainIdentifier(vaultUID), displayName: "Unlock Test Vault", pathRelativeToDocumentStorage: vaultUID)
		vaultAccount = VaultAccount(vaultUID: vaultUID, delegateAccountUID: "delegate-\(vaultUID)", vaultPath: CloudPath("/Vault"), vaultName: "Unlock Test Vault")

		let masterkey = try Masterkey.createFromRaw(rawKey: [UInt8](repeating: 0x55, count: 64))
		masterkeyFileData = try MasterkeyFile.lock(masterkey: masterkey, vaultVersion: 8, passphrase: passphrase, pepper: [UInt8](), scryptCostParam: 2)

		vaultCacheMock = CryptomatorCommonCore.VaultCacheMock()
		vaultCacheMock.getCachedVaultWithVaultUIDReturnValue = CachedVault(vaultUID: vaultUID, masterkeyFileData: masterkeyFileData, vaultConfigToken: nil, lastUpToDateCheck: Date(), masterkeyFileLastModifiedDate: nil, vaultConfigLastModifiedDate: nil)
		passwordManagerMock = CryptomatorCommonCore.VaultPasswordManagerMock()
		providerManagerMock = CloudProviderManagerStub()
		vaultAccountManagerMock = VaultAccountManagerStub(vaultAccount: vaultAccount)
		vaultUnlockingMock = VaultUnlockingMock()
		fileProviderConnectorMock = FileProviderConnectorMock()
		fileProviderConnectorMock.proxy = vaultUnlockingMock
	}

	// MARK: - Swallow-path (offline / cached-only signals)

	func testUnlockSwallowsCloudProviderNoInternetConnection() async throws {
		try await assertUnlockSucceeds(withRefreshError: CloudProviderError.noInternetConnection)
	}

	func testUnlockSwallowsLocalizedCloudProviderNoInternetConnection() async throws {
		try await assertUnlockSucceeds(withRefreshError: LocalizedCloudProviderError.noInternetConnection)
	}

	func testUnlockSwallowsNSURLErrorTimedOut() async throws {
		try await assertUnlockSucceeds(withRefreshError: NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut))
	}

	func testUnlockSwallowsNSURLErrorNotConnectedToInternet() async throws {
		try await assertUnlockSucceeds(withRefreshError: NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet))
	}

	func testUnlockSwallowsNSURLErrorNetworkConnectionLost() async throws {
		try await assertUnlockSucceeds(withRefreshError: NSError(domain: NSURLErrorDomain, code: NSURLErrorNetworkConnectionLost))
	}

	func testUnlockSwallowsLocalizedCloudProviderItemNotFound() async throws {
		try await assertUnlockSucceeds(withRefreshError: LocalizedCloudProviderError.itemNotFound(cloudPath: CloudPath("/Vault/masterkey.cryptomator")))
	}

	func testUnlockSwallowsCloudProviderItemNotFound() async throws {
		try await assertUnlockSucceeds(withRefreshError: CloudProviderError.itemNotFound)
	}

	// MARK: - Failure path (should still surface)

	func testUnlockRejectsLocalizedCloudProviderUnauthorized() async throws {
		try await assertUnlockFails(withRefreshError: LocalizedCloudProviderError.unauthorized)
	}

	func testUnlockRejectsNonTransientNSURLError() async throws {
		try await assertUnlockFails(withRefreshError: NSError(domain: NSURLErrorDomain, code: NSURLErrorUserCancelledAuthentication))
	}

	func testUnlockRejectsUnrelatedError() async throws {
		try await assertUnlockFails(withRefreshError: NSError(domain: "TestDomain", code: 42))
	}

	// MARK: - Helpers

	private func makeViewModel() -> UnlockVaultViewModel {
		return withDependencies({
			$0.fileProviderConnector = self.fileProviderConnectorMock
		}, operation: {
			UnlockVaultViewModel(domain: self.domain,
			                     wrongBiometricalPassword: false,
			                     passwordManager: self.passwordManagerMock,
			                     vaultAccountManager: self.vaultAccountManagerMock,
			                     providerManager: self.providerManagerMock,
			                     vaultCache: self.vaultCacheMock)
		})
	}

	private func assertUnlockSucceeds(withRefreshError refreshError: Error, file: StaticString = #filePath, line: UInt = #line) async throws {
		vaultCacheMock.refreshVaultCacheForWithThrowableError = refreshError
		let viewModel = makeViewModel()

		do {
			try await viewModel.unlock(withPassword: passphrase, storePasswordInKeychain: false)
		} catch {
			XCTFail("Expected unlock to succeed when refresh failed with swallowed error \(refreshError), but got \(error)", file: file, line: line)
		}
		XCTAssertEqual(1, vaultUnlockingMock.unlockVaultKekCallsCount, "XPC unlock should run after swallow", file: file, line: line)
	}

	private func assertUnlockFails(withRefreshError refreshError: Error, file: StaticString = #filePath, line: UInt = #line) async throws {
		vaultCacheMock.refreshVaultCacheForWithThrowableError = refreshError
		let viewModel = makeViewModel()

		await XCTAssertThrowsAsyncError(try await viewModel.unlock(withPassword: passphrase, storePasswordInKeychain: false), "Expected unlock to reject with refresh error \(refreshError), but it resolved", file: file, line: line)
		XCTAssertEqual(0, vaultUnlockingMock.unlockVaultKekCallsCount, "XPC unlock must not run on reject path", file: file, line: line)
	}
}

private class VaultAccountManagerStub: VaultAccountManager {
	private let vaultAccount: VaultAccount

	init(vaultAccount: VaultAccount) {
		self.vaultAccount = vaultAccount
	}

	func getAccount(with vaultUID: String) throws -> VaultAccount {
		return vaultAccount
	}

	func saveNewAccount(_ account: VaultAccount) throws {
		throw MockError.notMocked
	}

	func removeAccount(with vaultUID: String) throws {
		throw MockError.notMocked
	}

	func removeAccounts(with vaultUIDs: [String]) throws {
		throw MockError.notMocked
	}

	func getAllAccounts() throws -> [VaultAccount] {
		throw MockError.notMocked
	}

	func updateAccount(_ account: VaultAccount) throws {
		throw MockError.notMocked
	}
}

private class CloudProviderManagerStub: CloudProviderManager {
	let provider: CloudProvider = CryptomatorCommonCore.CloudProviderMock()

	func getProvider(with accountUID: String) throws -> CloudProvider {
		return provider
	}

	func getBackgroundSessionProvider(with accountUID: String, sessionIdentifier: String) throws -> CloudProvider {
		throw MockError.notMocked
	}
}
