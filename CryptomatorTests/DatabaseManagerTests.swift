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
}

extension VaultListPosition: Equatable {
	public static func == (lhs: VaultListPosition, rhs: VaultListPosition) -> Bool {
		return lhs.id == rhs.id && lhs.position == rhs.position && lhs.vaultUID == rhs.vaultUID
	}
}
