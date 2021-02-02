//
//  DatabaseManagerTests.swift
//  CryptomatorTests
//
//  Created by Philipp Schmid on 07.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//
import CryptomatorCloudAccess
import GRDB
import XCTest
@testable import CloudAccessPrivateCore
@testable import Cryptomator
class DatabaseManagerTests: XCTestCase {
	var tmpDir: URL!
	var dbPool: DatabasePool!
	var dbManager: DatabaseManager!
	var cryptomatorDB: CryptomatorDatabase!
	override func setUpWithError() throws {
		tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true, attributes: nil)
		let dbURL = tmpDir.appendingPathComponent("db.sqlite")
		dbPool = try CryptomatorDatabase.openSharedDatabase(at: dbURL)
		cryptomatorDB = try CryptomatorDatabase(dbPool)
		dbManager = try DatabaseManager(dbPool: dbPool)
	}

	override func tearDownWithError() throws {
		dbPool = nil
		cryptomatorDB = nil
		dbManager = nil
		try FileManager.default.removeItem(at: tmpDir)
	}

	// MARK: VaultListPosition

	func testCreatePositionTrigger() throws {
		let cloudAccountManager = CloudProviderAccountManager(dbPool: dbPool)
		let vaultAccountManager = VaultAccountManager(dbPool: dbPool)

		let cloudProviderAccount = CloudProviderAccount(accountUID: "1", cloudProviderType: .webDAV)
		try cloudAccountManager.saveNewAccount(cloudProviderAccount)
		let vaultAccount = VaultAccount(vaultUID: "Vault1", delegateAccountUID: cloudProviderAccount.accountUID, vaultPath: CloudPath("/Vault1"))
		try vaultAccountManager.saveNewAccount(vaultAccount)
		let firstVaultListPosition = try dbPool.read { db in
			try VaultListPosition.filter(Column("vaultUID") == "Vault1").fetchOne(db)
		}
		XCTAssertNotNil(firstVaultListPosition)
		XCTAssertEqual(0, firstVaultListPosition?.position)
		XCTAssertEqual(1, firstVaultListPosition?.id)

		let secondVaultAccount = VaultAccount(vaultUID: "Vault2", delegateAccountUID: cloudProviderAccount.accountUID, vaultPath: CloudPath("/Vault2"))
		try vaultAccountManager.saveNewAccount(secondVaultAccount)

		let secondVaultListPosition = try dbPool.read { db in
			try VaultListPosition.filter(Column("vaultUID") == "Vault2").fetchOne(db)
		}
		XCTAssertNotNil(secondVaultListPosition)
		XCTAssertEqual(1, secondVaultListPosition?.position)
		XCTAssertEqual(2, secondVaultListPosition?.id)
	}

	func testDeleteVaultAccountUpdatesPositions() throws {
		let cloudAccountManager = CloudProviderAccountManager(dbPool: dbPool)
		let vaultAccountManager = VaultAccountManager(dbPool: dbPool)

		let cloudProviderAccount = CloudProviderAccount(accountUID: "1", cloudProviderType: .webDAV)
		try cloudAccountManager.saveNewAccount(cloudProviderAccount)
		let vaultAccount = VaultAccount(vaultUID: "Vault1", delegateAccountUID: cloudProviderAccount.accountUID, vaultPath: CloudPath("/Vault1"))
		try vaultAccountManager.saveNewAccount(vaultAccount)
		let secondVaultAccount = VaultAccount(vaultUID: "Vault2", delegateAccountUID: cloudProviderAccount.accountUID, vaultPath: CloudPath("/Vault2"))
		try vaultAccountManager.saveNewAccount(secondVaultAccount)
		let thirdVaultAccount = VaultAccount(vaultUID: "Vault3", delegateAccountUID: cloudProviderAccount.accountUID, vaultPath: CloudPath("/Vault3"))
		try vaultAccountManager.saveNewAccount(thirdVaultAccount)

		_ = try dbPool.write { db in
			try vaultAccount.delete(db)
		}

		let vaultListPositionEntryForVault1 = try dbPool.read { db in
			try VaultListPosition.filter(Column("vaultUID") == "Vault1").fetchOne(db)
		}
		XCTAssertNil(vaultListPositionEntryForVault1)

		let firstVaultListPosition = try dbPool.read { db in
			try VaultListPosition.filter(Column("vaultUID") == "Vault2").fetchOne(db)
		}
		XCTAssertNotNil(firstVaultListPosition)
		XCTAssertEqual(0, firstVaultListPosition?.position)

		let secondVaultListPosition = try dbPool.read { db in
			try VaultListPosition.filter(Column("vaultUID") == "Vault3").fetchOne(db)
		}
		XCTAssertNotNil(secondVaultListPosition)
		XCTAssertEqual(1, secondVaultListPosition?.position)
	}

	func testUpdateVaultListPositions() throws {
		let cloudAccountManager = CloudProviderAccountManager(dbPool: dbPool)
		let vaultAccountManager = VaultAccountManager(dbPool: dbPool)

		let cloudProviderAccount = CloudProviderAccount(accountUID: "1", cloudProviderType: .webDAV)
		try cloudAccountManager.saveNewAccount(cloudProviderAccount)
		let vaultAccount = VaultAccount(vaultUID: "Vault1", delegateAccountUID: cloudProviderAccount.accountUID, vaultPath: CloudPath("/Vault1"))
		try vaultAccountManager.saveNewAccount(vaultAccount)
		let secondVaultAccount = VaultAccount(vaultUID: "Vault2", delegateAccountUID: cloudProviderAccount.accountUID, vaultPath: CloudPath("/Vault2"))
		try vaultAccountManager.saveNewAccount(secondVaultAccount)
		let thirdVaultAccount = VaultAccount(vaultUID: "Vault3", delegateAccountUID: cloudProviderAccount.accountUID, vaultPath: CloudPath("/Vault3"))
		try vaultAccountManager.saveNewAccount(thirdVaultAccount)

		let vaults = try dbManager.getAllVaults()

		let vaultListPositions = vaults.map { $0.vaultListPosition }
		let updatedVaultListPositions: [VaultListPosition] = vaultListPositions.map {
			var vaultListPosition = $0
			vaultListPosition.position! += 1
			return vaultListPosition
		}
		try dbManager.updateVaultListPositions(updatedVaultListPositions)

		let updatedVaults = try dbManager.getAllVaults()
		let fetchedVaultListPositions = updatedVaults.map { $0.vaultListPosition }

		let sortedUpdatedVaultListPositions = updatedVaultListPositions.sorted { $0.position! < $1.position! }
		let sortedFetchedVaultListPositions = fetchedVaultListPositions.sorted { $0.position! < $1.position! }
		XCTAssertEqual(sortedUpdatedVaultListPositions, sortedFetchedVaultListPositions)
	}

	// MARK: AccountListPosition

	func testCreateAccountListPositionTrigger() throws {
		let cloudAccountManager = CloudProviderAccountManager(dbPool: dbPool)

		let firstWebdavCloudProviderAccount = CloudProviderAccount(accountUID: "firstWebdavCloudProviderAccount", cloudProviderType: .webDAV)
		try cloudAccountManager.saveNewAccount(firstWebdavCloudProviderAccount)

		let secondWebdavCloudProviderAccount = CloudProviderAccount(accountUID: "secondWebdavCloudProviderAccount", cloudProviderType: .webDAV)
		try cloudAccountManager.saveNewAccount(secondWebdavCloudProviderAccount)

		let firstDropboxCloudProviderAccount = CloudProviderAccount(accountUID: "firstDropboxCloudProviderAccount", cloudProviderType: .dropbox)
		try cloudAccountManager.saveNewAccount(firstDropboxCloudProviderAccount)

		let firstWebDAVAccountListPosition = try dbPool.read { db in
			try AccountListPosition.filter(Column("accountUID") == "firstWebdavCloudProviderAccount" && Column("cloudProviderType") == "webDAV").fetchOne(db)
		}
		XCTAssertNotNil(firstWebDAVAccountListPosition)
		XCTAssertEqual(0, firstWebDAVAccountListPosition?.position)
		XCTAssertEqual(1, firstWebDAVAccountListPosition?.id)

		let secondWebDAVAccountListPosition = try dbPool.read { db in
			try AccountListPosition.filter(Column("accountUID") == "secondWebdavCloudProviderAccount" && Column("cloudProviderType") == "webDAV").fetchOne(db)
		}
		XCTAssertNotNil(secondWebDAVAccountListPosition)
		XCTAssertEqual(1, secondWebDAVAccountListPosition?.position)
		XCTAssertEqual(2, secondWebDAVAccountListPosition?.id)

		let firstDropboxAccountListPosition = try dbPool.read { db in
			try AccountListPosition.filter(Column("accountUID") == "firstDropboxCloudProviderAccount" && Column("cloudProviderType") == "dropbox").fetchOne(db)
		}
		XCTAssertNotNil(firstDropboxAccountListPosition)
		XCTAssertEqual(0, firstDropboxAccountListPosition?.position)
		XCTAssertEqual(3, firstDropboxAccountListPosition?.id)
	}

	func testDeleteCloudProviderAccountUpdatesPositions() throws {
		let cloudAccountManager = CloudProviderAccountManager(dbPool: dbPool)

		let firstWebdavCloudProviderAccount = CloudProviderAccount(accountUID: "firstWebdavCloudProviderAccount", cloudProviderType: .webDAV)
		try cloudAccountManager.saveNewAccount(firstWebdavCloudProviderAccount)

		let secondWebdavCloudProviderAccount = CloudProviderAccount(accountUID: "secondWebdavCloudProviderAccount", cloudProviderType: .webDAV)
		try cloudAccountManager.saveNewAccount(secondWebdavCloudProviderAccount)

		let thirdWebdavCloudProviderAccount = CloudProviderAccount(accountUID: "thirdWebdavCloudProviderAccount", cloudProviderType: .webDAV)
		try cloudAccountManager.saveNewAccount(thirdWebdavCloudProviderAccount)

		let firstDropboxCloudProviderAccount = CloudProviderAccount(accountUID: "firstDropboxCloudProviderAccount", cloudProviderType: .dropbox)
		try cloudAccountManager.saveNewAccount(firstDropboxCloudProviderAccount)

		_ = try dbPool.write { db in
			try firstWebdavCloudProviderAccount.delete(db)
		}

		let accountListPositionEntryForFirstWebDAVAccount = try dbPool.read { db in
			try AccountListPosition.filter(Column("accountUID") == "firstWebdavCloudProviderAccount").fetchOne(db)
		}
		XCTAssertNil(accountListPositionEntryForFirstWebDAVAccount)

		let firstAccountListPositionForWebDAV = try dbPool.read { db in
			try AccountListPosition.filter(Column("accountUID") == "secondWebdavCloudProviderAccount").fetchOne(db)
		}
		XCTAssertNotNil(firstAccountListPositionForWebDAV)
		XCTAssertEqual(0, firstAccountListPositionForWebDAV?.position)

		let secondAccountListPositionForWebDAV = try dbPool.read { db in
			try AccountListPosition.filter(Column("accountUID") == "thirdWebdavCloudProviderAccount").fetchOne(db)
		}
		XCTAssertNotNil(secondAccountListPositionForWebDAV)
		XCTAssertEqual(1, secondAccountListPositionForWebDAV?.position)

		let firstAccountListPositionForDropbox = try dbPool.read { db in
			try AccountListPosition.filter(Column("accountUID") == "firstDropboxCloudProviderAccount").fetchOne(db)
		}
		XCTAssertNotNil(firstAccountListPositionForDropbox)
		XCTAssertEqual(0, firstAccountListPositionForDropbox?.position)
	}

	func testUpdateAccountListPositions() throws {
		let cloudAccountManager = CloudProviderAccountManager(dbPool: dbPool)

		let firstWebdavCloudProviderAccount = CloudProviderAccount(accountUID: "firstWebdavCloudProviderAccount", cloudProviderType: .webDAV)
		try cloudAccountManager.saveNewAccount(firstWebdavCloudProviderAccount)

		let secondWebdavCloudProviderAccount = CloudProviderAccount(accountUID: "secondWebdavCloudProviderAccount", cloudProviderType: .webDAV)
		try cloudAccountManager.saveNewAccount(secondWebdavCloudProviderAccount)

		let thirdWebdavCloudProviderAccount = CloudProviderAccount(accountUID: "thirdWebdavCloudProviderAccount", cloudProviderType: .webDAV)
		try cloudAccountManager.saveNewAccount(thirdWebdavCloudProviderAccount)

		let accounts = try dbManager.getAllAccounts(for: .webDAV)

		XCTAssertEqual(3, accounts.count)

		let accountListPositions = accounts.map { $0.accountListPosition }
		let updatedAccountListPositions: [AccountListPosition] = accountListPositions.map {
			var accountListPosition = $0
			accountListPosition.position! += 1
			return accountListPosition
		}
		try dbManager.updateAccountListPositions(updatedAccountListPositions)

		let updatedAccounts = try dbManager.getAllAccounts(for: .webDAV)
		let fetchedAccountListPositions = updatedAccounts.map { $0.accountListPosition }

		let sortedUpdatedAccountListPositions = updatedAccountListPositions.sorted { $0.position! < $1.position! }
		let sortedFetchedAccountListPositions = fetchedAccountListPositions.sorted { $0.position! < $1.position! }
		XCTAssertEqual(sortedUpdatedAccountListPositions, sortedFetchedAccountListPositions)
	}

	func testGetAllAccountsIsFiltered() throws {
		let cloudAccountManager = CloudProviderAccountManager(dbPool: dbPool)

		let firstWebdavCloudProviderAccount = CloudProviderAccount(accountUID: "firstWebdavCloudProviderAccount", cloudProviderType: .webDAV)
		try cloudAccountManager.saveNewAccount(firstWebdavCloudProviderAccount)

		let secondWebdavCloudProviderAccount = CloudProviderAccount(accountUID: "secondWebdavCloudProviderAccount", cloudProviderType: .webDAV)
		try cloudAccountManager.saveNewAccount(secondWebdavCloudProviderAccount)

		let thirdWebdavCloudProviderAccount = CloudProviderAccount(accountUID: "thirdWebdavCloudProviderAccount", cloudProviderType: .webDAV)
		try cloudAccountManager.saveNewAccount(thirdWebdavCloudProviderAccount)

		let firstDropboxCloudProviderAccount = CloudProviderAccount(accountUID: "firstDropboxCloudProviderAccount", cloudProviderType: .dropbox)
		try cloudAccountManager.saveNewAccount(firstDropboxCloudProviderAccount)

		let webDAVAccounts = try dbManager.getAllAccounts(for: .webDAV)

		let expectedWebDAVAccountListPositions = [AccountListPosition(id: 1, position: 0, accountUID: firstWebdavCloudProviderAccount.accountUID),
		                                          AccountListPosition(id: 2, position: 1, accountUID: secondWebdavCloudProviderAccount.accountUID),
		                                          AccountListPosition(id: 3, position: 2, accountUID: thirdWebdavCloudProviderAccount.accountUID)]
		let expectedWebDAVCloudAccounts = [firstWebdavCloudProviderAccount, secondWebdavCloudProviderAccount, thirdWebdavCloudProviderAccount]
		let expectedWebDAVAccounts = expectedWebDAVAccountListPositions.enumerated().map { index, accountListPosition in
			AccountInfo(cloudProviderAccount: expectedWebDAVCloudAccounts[index], accountListPosition: accountListPosition)
		}
		XCTAssertEqual(expectedWebDAVAccounts, webDAVAccounts)

		let dropboxAccounts = try dbManager.getAllAccounts(for: .dropbox)
		let expectedDropboxAccounts = [AccountInfo(cloudProviderAccount: firstDropboxCloudProviderAccount,
		                                           accountListPosition: AccountListPosition(id: 4, position: 0, accountUID: firstDropboxCloudProviderAccount.accountUID))]
		XCTAssertEqual(expectedDropboxAccounts, dropboxAccounts)

		let googleDriveAccounts = try dbManager.getAllAccounts(for: .googleDrive)
		XCTAssertEqual(0, googleDriveAccounts.count)
	}
}

extension VaultListPosition: Equatable {
	public static func == (lhs: VaultListPosition, rhs: VaultListPosition) -> Bool {
		return lhs.id == rhs.id && lhs.position == rhs.position && lhs.vaultUID == rhs.vaultUID
	}
}

extension AccountListPosition: Equatable {
	public static func == (lhs: AccountListPosition, rhs: AccountListPosition) -> Bool {
		return lhs.id == rhs.id && lhs.position == rhs.position && lhs.accountUID == rhs.accountUID
	}
}

extension AccountInfo: Equatable {
	public static func == (lhs: AccountInfo, rhs: AccountInfo) -> Bool {
		return lhs.cloudProviderType == rhs.cloudProviderType && lhs.accountUID == rhs.accountUID && lhs.listPosition == rhs.listPosition
	}
}
