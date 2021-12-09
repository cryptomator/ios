//
//  CreateNewLocalVaultViewModelTests.swift
//  CryptomatorTests
//
//  Created by Philipp Schmid on 29.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import XCTest
@testable import Cryptomator

class CreateNewLocalVaultViewModelTests: AddLocalVaultViewModelTestCase {
	func testAddVault() throws {
		let expectation = XCTestExpectation()
		let viewModel = CreateNewLocalVaultViewModel(vaultName: "MyVault", selectedLocalFileSystemType: .custom, accountManager: accountManagerMock)
		let credential = LocalFileSystemCredential(rootURL: tmpDirURL, identifier: UUID().uuidString)
		viewModel.addVault(for: credential).then { result in
			XCTAssertEqual(credential, result.credential)
			XCTAssertEqual(credential.identifier, result.account.accountUID)
			XCTAssertEqual(CloudProviderType.localFileSystem(type: .custom), result.account.cloudProviderType)

			guard let chosenFolder = result.item as? Folder else {
				XCTFail("result item is not a Folder")
				return
			}
			XCTAssertEqual(CloudPath("/MyVault"), chosenFolder.path)

			XCTAssertEqual(1, self.accountManagerMock.savedAccounts.count)
			XCTAssertEqual(result.account, self.accountManagerMock.savedAccounts[0])
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testAddVaultWithNameCollision() throws {
		let expectation = XCTestExpectation()
		let viewModel = CreateNewLocalVaultViewModel(vaultName: "MyVault", selectedLocalFileSystemType: .custom, accountManager: accountManagerMock)
		try FileManager.default.createDirectory(at: tmpDirURL.appendingPathComponent("MyVault"), withIntermediateDirectories: false)
		let credential = LocalFileSystemCredential(rootURL: tmpDirURL, identifier: UUID().uuidString)
		viewModel.addVault(for: credential).then { _ in
			XCTFail("Promise fulfilled")
		}.catch { error in
			guard case CreateNewVaultChooseFolderViewModelError.vaultNameCollision = error else {
				XCTFail("Promise rejected with wrong error: \(error)")
				return
			}
			XCTAssertEqual(0, self.accountManagerMock.savedAccounts.count)
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testAddVaultWithExistingVaultAtChosenURL() throws {
		let expectation = XCTestExpectation()
		let viewModel = CreateNewLocalVaultViewModel(vaultName: "MyVault", selectedLocalFileSystemType: .custom, accountManager: accountManagerMock)
		try createVault(at: tmpDirURL)
		let credential = LocalFileSystemCredential(rootURL: tmpDirURL, identifier: UUID().uuidString)
		viewModel.addVault(for: credential).then { _ in
			XCTFail("Promise fulfilled")
		}.catch { error in
			guard case CreateNewLocalVaultViewModelError.detectedExistingVault = error else {
				XCTFail("Promise rejected with wrong error: \(error)")
				return
			}
			XCTAssertEqual(0, self.accountManagerMock.savedAccounts.count)
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testAddVaultWithExistingLegacyVaultAtChosenURL() throws {
		let expectation = XCTestExpectation()
		let viewModel = CreateNewLocalVaultViewModel(vaultName: "MyVault", selectedLocalFileSystemType: .custom, accountManager: accountManagerMock)
		try createLegacyVault(at: tmpDirURL)
		let credential = LocalFileSystemCredential(rootURL: tmpDirURL, identifier: UUID().uuidString)
		viewModel.addVault(for: credential).then { _ in
			XCTFail("Promise fulfilled")
		}.catch { error in
			guard case CreateNewLocalVaultViewModelError.detectedExistingVault = error else {
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
