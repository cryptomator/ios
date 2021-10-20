//
//  VaultListViewModelTests.swift
//  CryptomatorTests
//
//  Created by Philipp Schmid on 08.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import GRDB
import Promises
import XCTest
@testable import Cryptomator
@testable import CryptomatorCommonCore

class VaultListViewModelTests: XCTestCase {
	var tmpDir: URL!
	var dbPool: DatabasePool!
	var cryptomatorDB: CryptomatorDatabase!
	private var vaultManagerMock: VaultManagerMock!
	private var vaultAccountManagerMock: VaultAccountManagerMock!
	private var passwordManager: VaultPasswordKeychainManager!
	private var vaultCacheMock: VaultCacheMock!
	private var fileProviderConnectorMock: FileProviderConnectorMock!
	override func setUpWithError() throws {
		tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true, attributes: nil)
		let dbURL = tmpDir.appendingPathComponent("db.sqlite")
		dbPool = try CryptomatorDatabase.openSharedDatabase(at: dbURL)
		cryptomatorDB = try CryptomatorDatabase(dbPool)

		let cloudProviderManager = CloudProviderDBManager(accountManager: CloudProviderAccountDBManager(dbPool: dbPool))
		vaultAccountManagerMock = VaultAccountManagerMock()
		passwordManager = VaultPasswordKeychainManager()
		vaultCacheMock = VaultCacheMock()
		vaultManagerMock = VaultManagerMock(providerManager: cloudProviderManager, vaultAccountManager: vaultAccountManagerMock, vaultCache: vaultCacheMock, passwordManager: passwordManager)
		fileProviderConnectorMock = FileProviderConnectorMock()
		_ = try DatabaseManager(dbPool: dbPool)
	}

	override func tearDownWithError() throws {
		dbPool = nil
		cryptomatorDB = nil
		try FileManager.default.removeItem(at: tmpDir)
	}

	func testRefreshVaultsIsSorted() throws {
		let dbManagerMock = try DatabaseManagerMock(dbPool: dbPool)
		let vaultListViewModel = VaultListViewModel(dbManager: dbManagerMock, vaultManager: vaultManagerMock, fileProviderConnector: fileProviderConnectorMock)
		XCTAssert(vaultListViewModel.vaults.isEmpty)
		try vaultListViewModel.refreshItems()
		XCTAssertEqual(2, vaultListViewModel.vaults.count)
		XCTAssertEqual(0, vaultListViewModel.vaults[0].listPosition)
		XCTAssertEqual(1, vaultListViewModel.vaults[1].listPosition)

		XCTAssertEqual(1, dbManagerMock.vaults[0].listPosition)
		XCTAssertEqual(0, dbManagerMock.vaults[1].listPosition)
	}

	func testMoveRow() throws {
		let dbManagerMock = try DatabaseManagerMock(dbPool: dbPool)
		let vaultListViewModel = VaultListViewModel(dbManager: dbManagerMock, vaultManager: vaultManagerMock, fileProviderConnector: fileProviderConnectorMock)
		try vaultListViewModel.refreshItems()

		XCTAssertEqual(0, vaultListViewModel.vaults[0].listPosition)
		XCTAssertEqual(1, vaultListViewModel.vaults[1].listPosition)

		try vaultListViewModel.moveRow(at: 0, to: 1)
		XCTAssertEqual("vault1", vaultListViewModel.vaults[0].vaultListPosition.vaultUID)
		XCTAssertEqual(0, vaultListViewModel.vaults[0].listPosition)
		XCTAssertEqual("vault2", vaultListViewModel.vaults[1].vaultListPosition.vaultUID)
		XCTAssertEqual(1, vaultListViewModel.vaults[1].listPosition)

		XCTAssertEqual("vault1", dbManagerMock.updatedPositions[0].vaultUID)
		XCTAssertEqual(0, dbManagerMock.updatedPositions[0].position)
		XCTAssertEqual("vault2", dbManagerMock.updatedPositions[1].vaultUID)
		XCTAssertEqual(1, dbManagerMock.updatedPositions[1].position)
	}

	func testRemoveRow() throws {
		let cachedVault = CachedVault(vaultUID: "vault2", masterkeyFileData: "".data(using: .utf8)!, vaultConfigToken: nil, lastUpToDateCheck: Date())
		try vaultCacheMock.cache(cachedVault)
		try passwordManager.setPassword("pw", forVaultUID: "vault2")

		let dbManagerMock = try DatabaseManagerMock(dbPool: dbPool)
		let vaultListViewModel = VaultListViewModel(dbManager: dbManagerMock, vaultManager: vaultManagerMock, fileProviderConnector: fileProviderConnectorMock)
		try vaultListViewModel.refreshItems()

		XCTAssertEqual(0, vaultListViewModel.vaults[0].listPosition)
		XCTAssertEqual(1, vaultListViewModel.vaults[1].listPosition)

		try vaultListViewModel.removeRow(at: 0)

		XCTAssertEqual(1, dbManagerMock.updatedPositions.count)
		XCTAssertEqual("vault1", dbManagerMock.updatedPositions[0].vaultUID)
		XCTAssertEqual(0, dbManagerMock.updatedPositions[0].position)

		XCTAssertEqual("vault2", vaultAccountManagerMock.removedVaultUIDs[0])
		XCTAssertEqual(1, vaultManagerMock.removedFileProviderDomains.count)
		XCTAssertEqual("vault2", vaultManagerMock.removedFileProviderDomains[0])
		XCTAssertThrowsError(try passwordManager.getPassword(forVaultUID: "vault2")) { error in
			guard case VaultPasswordManagerError.passwordNotFound = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
		}
	}

	func testLockVault() throws {
		let expectation = XCTestExpectation()
		let dbManagerMock = try DatabaseManagerMock(dbPool: dbPool)
		let vaultListViewModel = VaultListViewModel(dbManager: dbManagerMock, vaultManager: vaultManagerMock, fileProviderConnector: fileProviderConnectorMock)
		let vaultInfo = VaultInfo(vaultAccount: VaultAccount(vaultUID: "vault1", delegateAccountUID: "1", vaultPath: CloudPath("/vault1"), vaultName: "vault1"),
		                          cloudProviderAccount: CloudProviderAccount(accountUID: "1", cloudProviderType: .webDAV),
		                          vaultListPosition: VaultListPosition(position: 1, vaultUID: "vault1"))
		let vaultLockingMock = VaultLockingMock()
		fileProviderConnectorMock.proxy = vaultLockingMock
		vaultListViewModel.lockVault(vaultInfo).then {
			XCTAssertEqual(NSFileProviderDomainIdentifier("vault1"), self.fileProviderConnectorMock.passedDomainIdentifier)
			XCTAssertEqual(NSFileProviderServiceName("org.cryptomator.ios.vault-locking"), self.fileProviderConnectorMock.passedServiceName)

			XCTAssertEqual(1, vaultLockingMock.lockedVaults.count)
			XCTAssertTrue(vaultLockingMock.lockedVaults.contains(NSFileProviderDomainIdentifier("vault1")))

			XCTAssertEqual(0, vaultLockingMock.unlockedVaults.count)
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testRefreshVaultLockedStates() throws {
		let expectation = XCTestExpectation()
		let dbManagerMock = try DatabaseManagerMock(dbPool: dbPool)
		let vaultListViewModel = VaultListViewModel(dbManager: dbManagerMock, vaultManager: vaultManagerMock, fileProviderConnector: fileProviderConnectorMock)
		try vaultListViewModel.refreshItems()

		XCTAssertTrue(vaultListViewModel.vaults.allSatisfy({ !$0.vaultIsUnlocked }))

		let vaultLockingMock = VaultLockingMock()
		fileProviderConnectorMock.proxy = vaultLockingMock

		// Simulate an unlocked vault
		vaultLockingMock.unlockedVaults.append(NSFileProviderDomainIdentifier("vault1"))

		vaultListViewModel.refreshVaultLockStates().then {
			XCTAssertNil(self.fileProviderConnectorMock.passedDomain)
			XCTAssertEqual(NSFileProviderServiceName("org.cryptomator.ios.vault-locking"), self.fileProviderConnectorMock.passedServiceName)

			XCTAssertEqual(1, vaultLockingMock.unlockedVaults.count)
			let unlockedVaults = vaultListViewModel.vaults.filter({ $0.vaultIsUnlocked })
			XCTAssertEqual(1, unlockedVaults.count)
			XCTAssertTrue(unlockedVaults.contains(where: { $0.vaultUID == "vault1" }))
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}
}

private class DatabaseManagerMock: DatabaseManager {
	var updatedPositions = [VaultListPosition]()
	let vaults = [VaultInfo(vaultAccount: VaultAccount(vaultUID: "vault1", delegateAccountUID: "1", vaultPath: CloudPath("/vault1"), vaultName: "vault1"),
	                        cloudProviderAccount: CloudProviderAccount(accountUID: "1", cloudProviderType: .webDAV),
	                        vaultListPosition: VaultListPosition(position: 1, vaultUID: "vault1")),
	              VaultInfo(vaultAccount: VaultAccount(vaultUID: "vault2", delegateAccountUID: "1", vaultPath: CloudPath("/vault1"), vaultName: "vautlt1"),
	                        cloudProviderAccount: CloudProviderAccount(accountUID: "1", cloudProviderType: .webDAV),
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
}

private class VaultManagerMock: VaultDBManager {
	var removedFileProviderDomains = [String]()
	override func removeFileProviderDomain(withVaultUID vaultUID: String) -> Promise<Void> {
		removedFileProviderDomains.append(vaultUID)
		return Promise(())
	}
}

class VaultCacheMock: VaultCache {
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

	func invalidate(vaultUID: String) throws {
		invalidatedVaults.append(vaultUID)
	}
}

class VaultLockingMock: VaultLocking {
	var lockedVaults = [NSFileProviderDomainIdentifier]()
	var unlockedVaults = [NSFileProviderDomainIdentifier]()

	func lockVault(domainIdentifier: NSFileProviderDomainIdentifier) {
		lockedVaults.append(domainIdentifier)
	}

	func getIsUnlockedVault(domainIdentifier: NSFileProviderDomainIdentifier, reply: @escaping (Bool) -> Void) {
		reply(unlockedVaults.contains(domainIdentifier))
	}

	func getUnlockedVaultDomainIdentifiers(reply: @escaping ([NSFileProviderDomainIdentifier]) -> Void) {
		reply(unlockedVaults)
	}

	let serviceName = NSFileProviderServiceName("org.cryptomator.ios.vault-locking")

	func makeListenerEndpoint() throws -> NSXPCListenerEndpoint {
		throw MockError.notMocked
	}
}

class FileProviderConnectorMock: FileProviderConnector {
	var proxy: Any?
	var passedServiceName: NSFileProviderServiceName?
	var passedDomainIdentifier: NSFileProviderDomainIdentifier?
	var passedDomain: NSFileProviderDomain?

	func getProxy<T>(serviceName: NSFileProviderServiceName, domainIdentifier: NSFileProviderDomainIdentifier) -> Promise<T> {
		passedServiceName = serviceName
		passedDomainIdentifier = domainIdentifier
		return getCastedProxy()
	}

	func getProxy<T>(serviceName: NSFileProviderServiceName, domain: NSFileProviderDomain?) -> Promise<T> {
		passedServiceName = serviceName
		passedDomain = domain
		return getCastedProxy()
	}

	private func getCastedProxy<T>() -> Promise<T> {
		guard let castedProxy = proxy as? T else {
			return Promise(FileProviderXPCConnectorError.typeMismatch)
		}
		return Promise(castedProxy)
	}
}
