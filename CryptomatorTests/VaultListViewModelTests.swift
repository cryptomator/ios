//
//  VaultListViewModelTests.swift
//  CryptomatorTests
//
//  Created by Philipp Schmid on 08.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import GRDB
import XCTest
@testable import CloudAccessPrivateCore
@testable import Cryptomator
class VaultListViewModelTests: XCTestCase {
	var tmpDir: URL!
	var dbPool: DatabasePool!
	var cryptomatorDB: CryptomatorDatabase!
	override func setUpWithError() throws {
		tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true, attributes: nil)
		let dbURL = tmpDir.appendingPathComponent("db.sqlite")
		dbPool = try CryptomatorDatabase.openSharedDatabase(at: dbURL)
		cryptomatorDB = try CryptomatorDatabase(dbPool)
		_ = try DatabaseManager(dbPool: dbPool)
	}

	override func tearDownWithError() throws {
		dbPool = nil
		cryptomatorDB = nil
		try FileManager.default.removeItem(at: tmpDir)
	}

	func testRefreshVaultsIsSorted() throws {
		let dbManagerMock = try DatabaseManagerMock(dbPool: dbPool)
		let vaultAccountManagerMock = VaultAccountManagerMock(dbPool: dbPool)
		let vaultListViewModel = VaultListViewModel(dbManager: dbManagerMock, vaultAccountManager: vaultAccountManagerMock)
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
		let vaultAccountManagerMock = VaultAccountManagerMock(dbPool: dbPool)
		let vaultListViewModel = VaultListViewModel(dbManager: dbManagerMock, vaultAccountManager: vaultAccountManagerMock)
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
		let dbManagerMock = try DatabaseManagerMock(dbPool: dbPool)
		let vaultAccountManagerMock = VaultAccountManagerMock(dbPool: dbPool)
		let vaultListViewModel = VaultListViewModel(dbManager: dbManagerMock, vaultAccountManager: vaultAccountManagerMock)
		try vaultListViewModel.refreshItems()

		XCTAssertEqual(0, vaultListViewModel.vaults[0].listPosition)
		XCTAssertEqual(1, vaultListViewModel.vaults[1].listPosition)

		try vaultListViewModel.removeRow(at: 0)

		XCTAssertEqual(1, dbManagerMock.updatedPositions.count)
		XCTAssertEqual("vault1", dbManagerMock.updatedPositions[0].vaultUID)
		XCTAssertEqual(0, dbManagerMock.updatedPositions[0].position)

		XCTAssertEqual("vault2", vaultAccountManagerMock.removedVaultUIDs[0])
	}
}

private class DatabaseManagerMock: DatabaseManager {
	var updatedPositions = [VaultListPosition]()
	let vaults = [VaultInfo(vaultAccount: VaultAccount(vaultUID: "vault1", delegateAccountUID: "1", vaultPath: CloudPath("/vault1")),
	                        cloudProviderAccount: CloudProviderAccount(accountUID: "1", cloudProviderType: .webDAV),
	                        vaultListPosition: VaultListPosition(position: 1, vaultUID: "vault1")),
	              VaultInfo(vaultAccount: VaultAccount(vaultUID: "vault2", delegateAccountUID: "1", vaultPath: CloudPath("/vault1")),
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
	var removedVaultUIDs = [String]()

	override func removeAccount(with vaultUID: String) throws {
		removedVaultUIDs.append(vaultUID)
	}
}
