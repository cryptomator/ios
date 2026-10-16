//
//  VaultListViewModelTests.swift
//  CryptomatorTests
//
//  Created by Philipp Schmid on 08.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Dependencies
import GRDB
import LocalAuthentication
import XCTest
@testable import Cryptomator
@testable import CryptomatorCommonCore

@MainActor
class VaultListViewModelTests: XCTestCase {
	private var vaultManagerMock: VaultDBManagerMock!
	private var vaultAccountManagerMock: VaultAccountManagerMock!
	private var passwordManagerMock: VaultPasswordManagerMock!
	private var vaultCacheMock: VaultCacheMock!
	private var fileProviderConnectorMock: FileProviderConnectorMock!

	override func setUp() async throws {
		try await super.setUp()
		let cloudProviderManager = CloudProviderDBManager(accountManager: CloudProviderAccountDBManager())
		vaultAccountManagerMock = VaultAccountManagerMock()
		passwordManagerMock = VaultPasswordManagerMock()
		vaultCacheMock = VaultCacheMock()
		vaultManagerMock = VaultDBManagerMock(providerManager: cloudProviderManager, vaultAccountManager: vaultAccountManagerMock, vaultCache: vaultCacheMock, passwordManager: passwordManagerMock, masterkeyCacheManager: MasterkeyCacheManagerMock(), masterkeyCacheHelper: MasterkeyCacheHelperMock())
		fileProviderConnectorMock = FileProviderConnectorMock()
	}

	func testRefreshVaultsIsSorted() throws {
		let dbManagerMock = DatabaseManagerMock()
		let vaultListViewModel = createVaultListViewModel(dbManager: dbManagerMock)
		XCTAssert(vaultListViewModel.getVaults().isEmpty)
		try vaultListViewModel.refreshItems()
		XCTAssertEqual(2, vaultListViewModel.getVaults().count)
		XCTAssertEqual(0, vaultListViewModel.getVaults()[0].listPosition)
		XCTAssertEqual(1, vaultListViewModel.getVaults()[1].listPosition)

		XCTAssertEqual(1, dbManagerMock.vaults[0].listPosition)
		XCTAssertEqual(0, dbManagerMock.vaults[1].listPosition)
	}

	func testMoveRow() throws {
		let dbManagerMock = DatabaseManagerMock()
		let vaultListViewModel = createVaultListViewModel(dbManager: dbManagerMock)
		try vaultListViewModel.refreshItems()

		XCTAssertEqual(0, vaultListViewModel.getVaults()[0].listPosition)
		XCTAssertEqual(1, vaultListViewModel.getVaults()[1].listPosition)

		try vaultListViewModel.moveRow(at: 0, to: 1)
		XCTAssertEqual("vault1", vaultListViewModel.getVaults()[0].vaultListPosition.vaultUID)
		XCTAssertEqual(0, vaultListViewModel.getVaults()[0].listPosition)
		XCTAssertEqual("vault2", vaultListViewModel.getVaults()[1].vaultListPosition.vaultUID)
		XCTAssertEqual(1, vaultListViewModel.getVaults()[1].listPosition)

		XCTAssertEqual("vault1", dbManagerMock.updatedPositions[0].vaultUID)
		XCTAssertEqual(0, dbManagerMock.updatedPositions[0].position)
		XCTAssertEqual("vault2", dbManagerMock.updatedPositions[1].vaultUID)
		XCTAssertEqual(1, dbManagerMock.updatedPositions[1].position)
	}

	func testRemoveRow() async throws {
		let cachedVault = CachedVault(vaultUID: "vault2", masterkeyFileData: Data("".utf8), vaultConfigToken: nil, lastUpToDateCheck: Date(), masterkeyFileLastModifiedDate: nil, vaultConfigLastModifiedDate: nil)
		try vaultCacheMock.cache(cachedVault)

		let dbManagerMock = DatabaseManagerMock()
		let vaultListViewModel = createVaultListViewModel(dbManager: dbManagerMock)
		try vaultListViewModel.refreshItems()

		XCTAssertEqual(0, vaultListViewModel.getVaults()[0].listPosition)
		XCTAssertEqual(1, vaultListViewModel.getVaults()[1].listPosition)

		try vaultListViewModel.removeRow(at: 0)
		for removalTask in vaultManagerMock.removalTasks {
			await removalTask.value
		}

		// No renumber on delete: positions may have gaps and we don't update here
		XCTAssertEqual(0, dbManagerMock.updatedPositions.count)

		XCTAssertEqual("vault2", vaultAccountManagerMock.removedVaultUIDs[0])
		XCTAssertEqual(1, vaultManagerMock.removedFileProviderDomains.count)
		XCTAssertEqual("vault2", vaultManagerMock.removedFileProviderDomains[0])

		XCTAssertEqual(1, passwordManagerMock.removedPasswordForVaultUIDs.count)
		XCTAssert(passwordManagerMock.removedPasswordForVaultUIDs.contains(where: { $0 == "vault2" }))
	}

	func testLockVault() async throws {
		let dbManagerMock = DatabaseManagerMock()
		let vaultListViewModel = createVaultListViewModel(dbManager: dbManagerMock)
		let vaultInfo = VaultInfo(vaultAccount: VaultAccount(vaultUID: "vault1", delegateAccountUID: "1", vaultPath: CloudPath("/vault1"), vaultName: "vault1"),
		                          cloudProviderAccount: CloudProviderAccount(accountUID: "1", cloudProviderType: .dropbox),
		                          vaultListPosition: VaultListPosition(position: 1, vaultUID: "vault1"))
		let vaultLockingMock = VaultLockingMock()
		fileProviderConnectorMock.proxy = vaultLockingMock
		try await withDependencies {
			$0.fileProviderConnector = fileProviderConnectorMock
		} operation: {
			try await vaultListViewModel.lockVault(vaultInfo)
		}
		XCTAssertEqual(NSFileProviderDomainIdentifier("vault1"), fileProviderConnectorMock.passedDomainIdentifier)
		XCTAssertEqual(NSFileProviderServiceName("org.cryptomator.ios.vault-locking"), fileProviderConnectorMock.passedServiceName)

		XCTAssertEqual(1, vaultLockingMock.lockedVaults.count)
		XCTAssertTrue(vaultLockingMock.lockedVaults.contains(NSFileProviderDomainIdentifier("vault1")))

		XCTAssertEqual(0, vaultLockingMock.unlockedVaults.count)
		XCTAssertEqual(1, fileProviderConnectorMock.xpcInvalidationCallCount)
	}

	func testRefreshVaultLockedStates() async throws {
		let dbManagerMock = DatabaseManagerMock()
		let vaultListViewModel = createVaultListViewModel(dbManager: dbManagerMock)
		try vaultListViewModel.refreshItems()

		XCTAssertTrue(vaultListViewModel.getVaults().allSatisfy({ !$0.vaultIsUnlocked.value }))

		let vaultLockingMock = VaultLockingMock()
		fileProviderConnectorMock.proxy = vaultLockingMock

		// Simulate an unlocked vault
		vaultLockingMock.unlockedVaults.append(NSFileProviderDomainIdentifier("vault1"))

		await withDependencies {
			$0.fileProviderConnector = fileProviderConnectorMock
		} operation: {
			await vaultListViewModel.refreshVaultLockStates()
		}
		XCTAssertEqual(NSFileProviderServiceName("org.cryptomator.ios.vault-locking"), fileProviderConnectorMock.passedServiceName)
		XCTAssertEqual(Set([NSFileProviderDomainIdentifier("vault1"), NSFileProviderDomainIdentifier("vault2")]), Set(fileProviderConnectorMock.passedDomainIdentifiers))

		let unlockedVaults = vaultListViewModel.getVaults().filter({ $0.vaultIsUnlocked.value })
		XCTAssertEqual(1, unlockedVaults.count)
		XCTAssertTrue(unlockedVaults.contains(where: { $0.vaultUID == "vault1" }))
		XCTAssertEqual(2, fileProviderConnectorMock.xpcInvalidationCallCount)
	}

	private func createVaultListViewModel(dbManager: DatabaseManager) -> VaultListViewModel {
		return withDependencies {
			$0.fileProviderConnector = FileProviderConnectorMock()
		} operation: {
			VaultListViewModel(dbManager: dbManager, vaultManager: vaultManagerMock)
		}
	}
}

extension VaultListViewModel {
	func getVaults() -> [VaultInfo] {
		return vaultCellViewModels.map { $0.vault }
	}
}

private class DatabaseManagerMock: DatabaseManager {
	var updatedPositions = [VaultListPosition]()
	let vaults = [VaultInfo(vaultAccount: VaultAccount(vaultUID: "vault1", delegateAccountUID: "1", vaultPath: CloudPath("/vault1"), vaultName: "vault1"),
	                        cloudProviderAccount: CloudProviderAccount(accountUID: "1", cloudProviderType: .dropbox),
	                        vaultListPosition: VaultListPosition(position: 1, vaultUID: "vault1")),
	              VaultInfo(vaultAccount: VaultAccount(vaultUID: "vault2", delegateAccountUID: "1", vaultPath: CloudPath("/vault1"), vaultName: "vautlt1"),
	                        cloudProviderAccount: CloudProviderAccount(accountUID: "1", cloudProviderType: .dropbox),
	                        vaultListPosition: VaultListPosition(position: 0, vaultUID: "vault2"))]

	override func getAllVaults() throws -> [VaultInfo] {
		return vaults
	}

	override func updateVaultListPositions(_ positions: [VaultListPosition]) throws {
		updatedPositions = positions
	}
}

private class VaultAccountManagerMock: VaultAccountManager {
	func updateAccount(_ account: VaultAccount) throws {
		throw MockError.notMocked
	}

	func saveNewAccount(_ account: VaultAccount) throws {
		throw MockError.notMocked
	}

	func getAccount(with vaultUID: String) throws -> VaultAccount {
		throw MockError.notMocked
	}

	func getAllAccounts() throws -> [VaultAccount] {
		throw MockError.notMocked
	}

	var removedVaultUIDs = [String]()

	func removeAccount(with vaultUID: String) throws {
		removedVaultUIDs.append(vaultUID)
	}

	func removeAccounts(with vaultUIDs: [String]) throws {
		removedVaultUIDs.append(contentsOf: vaultUIDs)
	}
}

/// @unchecked Sendable: test double, only touched from the test and from the removal tasks it awaits
private final class VaultDBManagerMock: VaultDBManager, @unchecked Sendable {
	var removedFileProviderDomains = [String]()
	var removalTasks = [Task<Void, Never>]()

	override func removeVault(withUID vaultUID: String) throws -> Task<Void, Never> {
		let removalTask = try super.removeVault(withUID: vaultUID)
		removalTasks.append(removalTask)
		return removalTask
	}

	override func removeFileProviderDomain(withVaultUID vaultUID: String) async throws {
		removedFileProviderDomains.append(vaultUID)
	}
}

/// @unchecked Sendable: test double, never touched concurrently
final class VaultCacheMock: VaultCache, @unchecked Sendable {
	var cachedVaults = [String: CachedVault]()
	var invalidatedVaults = [String]()

	func cache(_ entry: CachedVault) throws {
		cachedVaults[entry.vaultUID] = entry
	}

	func getCachedVault(withVaultUID vaultUID: String) throws -> CachedVault {
		guard let vault = cachedVaults[vaultUID] else {
			throw VaultCacheError.vaultNotFound
		}
		return vault
	}

	func setMasterkeyFileData(_ data: Data, forVaultUID vaultUID: String, lastModifiedDate: Date?) throws {
		throw MockError.notMocked
	}

	func refreshVaultCache(for vault: VaultAccount, with provider: CloudProvider) async throws {
		throw MockError.notMocked
	}
}

class VaultLockingMock: VaultLocking {
	var lockedVaults = [NSFileProviderDomainIdentifier]()
	var unlockedVaults = [NSFileProviderDomainIdentifier]()

	func lockVault(domainIdentifier: NSFileProviderDomainIdentifier) {
		lockedVaults.append(domainIdentifier)
	}

	func gracefulLockVault(domainIdentifier: NSFileProviderDomainIdentifier, reply: @escaping (Error?) -> Void) {
		lockedVaults.append(domainIdentifier)
		reply(nil)
	}

	func getIsUnlockedVault(domainIdentifier: NSFileProviderDomainIdentifier, reply: @escaping (Bool) -> Void) {
		reply(unlockedVaults.contains(domainIdentifier))
	}

	let serviceName = NSFileProviderServiceName("org.cryptomator.ios.vault-locking")

	func makeListenerEndpoint() throws -> NSXPCListenerEndpoint {
		throw MockError.notMocked
	}
}

private class VaultPasswordManagerMock: VaultPasswordManager {
	var removedPasswordForVaultUIDs = [String]()

	func setPassword(_ password: String, forVaultUID vaultUID: String) throws {
		throw MockError.notMocked
	}

	func getPassword(forVaultUID vaultUID: String, context: LAContext) throws -> String {
		throw MockError.notMocked
	}

	func removePassword(forVaultUID vaultUID: String) throws {
		removedPasswordForVaultUIDs.append(vaultUID)
	}

	func hasPassword(forVaultUID vaultUID: String) throws -> Bool {
		throw MockError.notMocked
	}
}
