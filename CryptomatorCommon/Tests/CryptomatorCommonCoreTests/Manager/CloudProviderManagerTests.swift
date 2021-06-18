//
//  CloudProviderManagerTests.swift
//  CryptomatorCommonCoreTests
//
//  Created by Philipp Schmid on 21.10.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation
import GRDB
import XCTest
@testable import CryptomatorCommonCore

class CloudProviderManagerTests: XCTestCase {
	var manager: CloudProviderDBManager!
	var accountManager: CloudProviderAccountDBManager!
	var tmpDir: URL!
	override func setUpWithError() throws {
		tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true, attributes: nil)
		let dbPool = try DatabasePool(path: tmpDir.appendingPathComponent("db.sqlite").path)
		try dbPool.write { db in
			try db.create(table: CloudProviderAccount.databaseTableName) { table in
				table.column(CloudProviderAccount.accountUIDKey, .text).primaryKey()
				table.column(CloudProviderAccount.cloudProviderTypeKey, .text).notNull()
			}
		}
		accountManager = CloudProviderAccountDBManager(dbPool: dbPool)
		manager = CloudProviderDBManager(accountManager: accountManager)
	}

	override func tearDownWithError() throws {
		try FileManager.default.removeItem(at: tmpDir)
	}

	func testCreateProviderCachesTheProvider() throws {
		DropboxSetup.constants = DropboxSetup(appKey: "", sharedContainerIdentifier: nil, keychainService: nil, forceForegroundSession: false)
		let account = CloudProviderAccount(accountUID: UUID().uuidString, cloudProviderType: .dropbox)
		try accountManager.saveNewAccount(account)
		XCTAssertNil(CloudProviderDBManager.cachedProvider[account.accountUID])
		let provider = try manager.getProvider(with: account.accountUID)
		guard provider is DropboxCloudProvider else {
			XCTFail("Provider has wrong type")
			return
		}
		XCTAssertNotNil(CloudProviderDBManager.cachedProvider[account.accountUID])
	}
}
