//
//  CloudProviderManagerTests.swift
//  CloudAccessPrivateCore
//
//  Created by Philipp Schmid on 21.10.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Foundation
import GRDB
import XCTest
@testable import CloudAccessPrivateCore

class CloudProviderManagerTests: XCTestCase {
	var manager: CloudProviderManager!
	var accountManager: CloudProviderAccountManager!
	override func setUpWithError() throws {
		let dbQueue = DatabaseQueue()
		try dbQueue.write { db in
			try db.create(table: CloudProviderAccount.databaseTableName) { table in
				table.column(CloudProviderAccount.accountUIDKey, .text).primaryKey()
				table.column(CloudProviderAccount.cloudProviderTypeKey, .text).notNull()
			}
		}
		accountManager = CloudProviderAccountManager(dbQueue: dbQueue)
		manager = CloudProviderManager(accountManager: accountManager)
	}

	func testCreateProviderCachesTheProvider() throws {
		let account = CloudProviderAccount(accountUID: UUID().uuidString, cloudProviderType: .dropbox)
		try accountManager.saveNewAccount(account)
		XCTAssertNil(CloudProviderManager.cachedProvider[account.accountUID])
		let provider = try manager.getProvider(with: account.accountUID)
		guard provider is DropboxCloudProvider else {
			XCTFail("Provider has wrong type")
			return
		}
		XCTAssertNotNil(CloudProviderManager.cachedProvider[account.accountUID])
	}
}
