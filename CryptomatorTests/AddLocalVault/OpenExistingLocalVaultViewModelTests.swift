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

	override func setUpWithError() throws {
		try super.setUpWithError()
		viewModel = OpenExistingLocalVaultViewModel(selectedLocalFileSystemType: .custom, accountManager: accountManagerMock)
	}

	func testAddVault() throws {
		let expectation = XCTestExpectation()
		let vaultURL = tmpDirURL.appendingPathComponent("MyVault")
		try createVault(at: vaultURL)
		let rootURL = vaultURL.appendingPathComponent("/")
		let credential = LocalFileSystemCredential(rootURL: rootURL, identifier: UUID().uuidString)
		viewModel.addVault(for: credential).then { result in
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

			XCTAssertEqual(1, self.accountManagerMock.savedAccounts.count)
			XCTAssertEqual(result.account, self.accountManagerMock.savedAccounts[0])
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testAddLegacyVault() throws {
		let expectation = XCTestExpectation()
		let vaultURL = tmpDirURL.appendingPathComponent("MyLegacyVault")
		try createLegacyVault(at: vaultURL)
		let rootURL = vaultURL.appendingPathComponent("/")
		let credential = LocalFileSystemCredential(rootURL: rootURL, identifier: UUID().uuidString)
		viewModel.addVault(for: credential).then { result in
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

			XCTAssertEqual(1, self.accountManagerMock.savedAccounts.count)
			XCTAssertEqual(result.account, self.accountManagerMock.savedAccounts[0])
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testAddVaultWithMissingVault() throws {
		let expectation = XCTestExpectation()
		let credential = LocalFileSystemCredential(rootURL: tmpDirURL, identifier: UUID().uuidString)
		viewModel.addVault(for: credential).then { _ in
			XCTFail("Promise fulfilled")
		}.catch { error in
			guard case OpenExistingLocalVaultViewModelError.noVaultFound = error else {
				XCTFail("Promise rejected with wrong error: \(error)")
				return
			}
			XCTAssertEqual(0, self.accountManagerMock.savedAccounts.count)
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}
}
