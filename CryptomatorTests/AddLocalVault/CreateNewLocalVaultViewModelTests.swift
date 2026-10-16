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
	func testAddVault() async throws {
		let viewModel = CreateNewLocalVaultViewModel(vaultName: "MyVault", selectedLocalFileSystemType: .custom, accountManager: accountManagerMock)
		let credential = LocalFileSystemCredential(rootURL: tmpDirURL, identifier: UUID().uuidString)
		let result = try await viewModel.addVault(for: credential)
		XCTAssertEqual(credential, result.credential)
		XCTAssertEqual(credential.identifier, result.account.accountUID)
		XCTAssertEqual(CloudProviderType.localFileSystem(type: .custom), result.account.cloudProviderType)

		guard let chosenFolder = result.item as? Folder else {
			XCTFail("result item is not a Folder")
			return
		}
		XCTAssertEqual(CloudPath("/MyVault"), chosenFolder.path)

		XCTAssertEqual(1, accountManagerMock.savedAccounts.count)
		XCTAssertEqual(result.account, accountManagerMock.savedAccounts[0])
	}

	func testAddVaultWithNameCollision() async throws {
		let viewModel = CreateNewLocalVaultViewModel(vaultName: "MyVault", selectedLocalFileSystemType: .custom, accountManager: accountManagerMock)
		try FileManager.default.createDirectory(at: tmpDirURL.appendingPathComponent("MyVault"), withIntermediateDirectories: false)
		let credential = LocalFileSystemCredential(rootURL: tmpDirURL, identifier: UUID().uuidString)
		await XCTAssertThrowsAsyncError(try await viewModel.addVault(for: credential)) { error in
			guard case CreateNewVaultChooseFolderViewModelError.vaultNameCollision = error else {
				XCTFail("Threw wrong error: \(error)")
				return
			}
		}
		XCTAssertEqual(0, accountManagerMock.savedAccounts.count)
	}

	func testAddVaultWithExistingVaultAtChosenURL() async throws {
		let viewModel = CreateNewLocalVaultViewModel(vaultName: "MyVault", selectedLocalFileSystemType: .custom, accountManager: accountManagerMock)
		try createVault(at: tmpDirURL)
		let credential = LocalFileSystemCredential(rootURL: tmpDirURL, identifier: UUID().uuidString)
		await XCTAssertThrowsAsyncError(try await viewModel.addVault(for: credential)) { error in
			guard case CreateNewLocalVaultViewModelError.detectedExistingVault = error else {
				XCTFail("Threw wrong error: \(error)")
				return
			}
		}
		XCTAssertEqual(0, accountManagerMock.savedAccounts.count)
	}

	func testAddVaultWithExistingLegacyVaultAtChosenURL() async throws {
		let viewModel = CreateNewLocalVaultViewModel(vaultName: "MyVault", selectedLocalFileSystemType: .custom, accountManager: accountManagerMock)
		try createLegacyVault(at: tmpDirURL)
		let credential = LocalFileSystemCredential(rootURL: tmpDirURL, identifier: UUID().uuidString)
		await XCTAssertThrowsAsyncError(try await viewModel.addVault(for: credential)) { error in
			guard case CreateNewLocalVaultViewModelError.detectedExistingVault = error else {
				XCTFail("Threw wrong error: \(error)")
				return
			}
		}
		XCTAssertEqual(0, accountManagerMock.savedAccounts.count)
	}
}
