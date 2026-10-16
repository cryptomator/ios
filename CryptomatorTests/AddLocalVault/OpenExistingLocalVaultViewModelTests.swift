//
//  OpenExistingLocalVaultViewModelTests.swift
//  CryptomatorTests
//
//  Created by Philipp Schmid on 29.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import XCTest
@testable import Cryptomator

class OpenExistingLocalVaultViewModelTests: AddLocalVaultViewModelTestCase {
	var viewModel: OpenExistingLocalVaultViewModel!

	override func setUp() async throws {
		try await super.setUp()
		viewModel = OpenExistingLocalVaultViewModel(selectedLocalFileSystemType: .custom, accountManager: accountManagerMock)
	}

	func testAddVault() async throws {
		let vaultURL = tmpDirURL.appendingPathComponent("MyVault")
		try createVault(at: vaultURL)
		let rootURL = vaultURL.appendingPathComponent("/")
		let credential = LocalFileSystemCredential(rootURL: rootURL, identifier: UUID().uuidString)
		let result = try await viewModel.addVault(for: credential)
		XCTAssertEqual(credential, result.credential)
		XCTAssertEqual(credential.identifier, result.account.accountUID)
		XCTAssertEqual(CloudProviderType.localFileSystem(type: .custom), result.account.cloudProviderType)

		guard let vaultDetailItem = result.item as? VaultDetailItem else {
			XCTFail("result item is not a VaultDetailItem")
			return
		}
		XCTAssertEqual("MyVault", vaultDetailItem.name)
		XCTAssertEqual(CloudPath("/"), vaultDetailItem.path)
		XCTAssertFalse(vaultDetailItem.isLegacyVault)

		XCTAssertEqual(1, accountManagerMock.savedAccounts.count)
		XCTAssertEqual(result.account, accountManagerMock.savedAccounts[0])
	}

	func testAddLegacyVault() async throws {
		let vaultURL = tmpDirURL.appendingPathComponent("MyLegacyVault")
		try createLegacyVault(at: vaultURL)
		let rootURL = vaultURL.appendingPathComponent("/")
		let credential = LocalFileSystemCredential(rootURL: rootURL, identifier: UUID().uuidString)
		let result = try await viewModel.addVault(for: credential)
		XCTAssertEqual(credential, result.credential)
		XCTAssertEqual(credential.identifier, result.account.accountUID)
		XCTAssertEqual(CloudProviderType.localFileSystem(type: .custom), result.account.cloudProviderType)

		guard let vaultDetailItem = result.item as? VaultDetailItem else {
			XCTFail("result item is not a VaultDetailItem")
			return
		}
		XCTAssertEqual("MyLegacyVault", vaultDetailItem.name)
		XCTAssertEqual(CloudPath("/"), vaultDetailItem.path)
		XCTAssertTrue(vaultDetailItem.isLegacyVault)

		XCTAssertEqual(1, accountManagerMock.savedAccounts.count)
		XCTAssertEqual(result.account, accountManagerMock.savedAccounts[0])
	}

	func testAddVaultWithMissingVault() async {
		let credential = LocalFileSystemCredential(rootURL: tmpDirURL, identifier: UUID().uuidString)
		await XCTAssertThrowsAsyncError(try await viewModel.addVault(for: credential)) { error in
			guard case OpenExistingLocalVaultViewModelError.noVaultFound = error else {
				XCTFail("Threw wrong error: \(error)")
				return
			}
		}
		XCTAssertEqual(0, accountManagerMock.savedAccounts.count)
	}
}
