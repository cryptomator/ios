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

	override func setUpWithError() throws {
		accountManager = CloudProviderAccountDBManager()
		manager = CloudProviderDBManager(accountManager: accountManager)
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
