//
//  CreateNewVaultPasswordViewModelTests.swift
//  CryptomatorTests
//
//  Created by Philipp Schmid on 18.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import Promises
import XCTest
@testable import Cryptomator
class CreateNewVaultPasswordViewModelTests: XCTestCase {
	private var vaultManagerMock: VaultManagerMock!

	override func setUpWithError() throws {
		vaultManagerMock = VaultManagerMock()
	}

	func testCreateNewVault() throws {
		let expectation = XCTestExpectation()
		let vaultPath = CloudPath("/Vault")
		let account = CloudProviderAccount(accountUID: "1", cloudProviderType: .webDAV)
		let vaultUID = "12345"
		let password = "TestPassword"

		let viewModel = CreateNewVaultPasswordViewModel(vaultPath: vaultPath, account: account, vaultUID: vaultUID)
		viewModel.password = password
		viewModel.confirmingPassword = password
		viewModel.createNewVault().then {
			XCTAssertEqual(1, self.vaultManagerMock.createdVaults.count)
			let createdVault = self.vaultManagerMock.createdVaults[0]
			XCTAssertEqual(vaultUID, createdVault.vaultUID)
			XCTAssertEqual("1", createdVault.delegateAccountUID)
			XCTAssertEqual(vaultPath, createdVault.vaultPath)
			XCTAssertEqual(password, createdVault.password)
			XCTAssert(createdVault.storePasswordInKeychain)
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testCreateNewVaultWithNotSetPassword() throws {
		let expectation = XCTestExpectation()
		let vaultPath = CloudPath("/Vault")
		let account = CloudProviderAccount(accountUID: "1", cloudProviderType: .webDAV)
		let vaultUID = "12345"

		let viewModel = CreateNewVaultPasswordViewModel(vaultPath: vaultPath, account: account, vaultUID: vaultUID)
		XCTAssertNil(viewModel.password)
		viewModel.createNewVault().then {
			XCTFail("Promise fulfilled")
		}.catch { error in
			guard case CreateNewVaultPasswordViewModelError.emptyPassword = error else {
				XCTFail("Promise rejected with wrong error: \(error)")
				return
			}
			XCTAssertEqual(0, self.vaultManagerMock.createdVaults.count)
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	// MARK: - validatePassword

	func testValidatePassword() throws {
		let vaultPath = CloudPath("/Vault")
		let account = CloudProviderAccount(accountUID: "1", cloudProviderType: .webDAV)
		let vaultUID = "12345"
		let password = "TestPassword"

		let viewModel = CreateNewVaultPasswordViewModel(vaultPath: vaultPath, account: account, vaultUID: vaultUID)
		viewModel.password = password
		viewModel.confirmingPassword = password
		try viewModel.validatePassword()
	}

	func testValidatePasswordWithNotSetConfirmingPassword() throws {
		let vaultPath = CloudPath("/Vault")
		let account = CloudProviderAccount(accountUID: "1", cloudProviderType: .webDAV)
		let vaultUID = "12345"
		let password = "TestPassword"

		let viewModel = CreateNewVaultPasswordViewModel(vaultPath: vaultPath, account: account, vaultUID: vaultUID)
		viewModel.password = password
		XCTAssertNil(viewModel.confirmingPassword)
		XCTAssertThrowsError(try viewModel.validatePassword()) { error in
			guard case CreateNewVaultPasswordViewModelError.nonMatchingPasswords = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
			XCTAssertEqual(0, self.vaultManagerMock.createdVaults.count)
		}
	}

	func testCreateNewVaultWithEmptyPassword() throws {
		let vaultPath = CloudPath("/Vault")
		let account = CloudProviderAccount(accountUID: "1", cloudProviderType: .webDAV)
		let vaultUID = "12345"

		let viewModel = CreateNewVaultPasswordViewModel(vaultPath: vaultPath, account: account, vaultUID: vaultUID)
		viewModel.password = ""
		XCTAssertThrowsError(try viewModel.validatePassword()) { error in
			guard case CreateNewVaultPasswordViewModelError.emptyPassword = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
			XCTAssertEqual(0, self.vaultManagerMock.createdVaults.count)
		}
	}

	func testCreateNewVaultWithEmptyConfirmingPassword() throws {
		let vaultPath = CloudPath("/Vault")
		let account = CloudProviderAccount(accountUID: "1", cloudProviderType: .webDAV)
		let vaultUID = "12345"
		let password = "TestPassword"

		let viewModel = CreateNewVaultPasswordViewModel(vaultPath: vaultPath, account: account, vaultUID: vaultUID)
		viewModel.password = password
		viewModel.confirmingPassword = ""
		XCTAssertThrowsError(try viewModel.validatePassword()) { error in
			guard case CreateNewVaultPasswordViewModelError.nonMatchingPasswords = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
			XCTAssertEqual(0, self.vaultManagerMock.createdVaults.count)
		}
	}

	func testCreateNewVaultWithNonMatchingNonEmptyPasswords() throws {
		let vaultPath = CloudPath("/Vault")
		let account = CloudProviderAccount(accountUID: "1", cloudProviderType: .webDAV)
		let vaultUID = "12345"
		let password = "TestPassword"

		let viewModel = CreateNewVaultPasswordViewModel(vaultPath: vaultPath, account: account, vaultUID: vaultUID)
		viewModel.password = password
		viewModel.confirmingPassword = "\(password)a"
		XCTAssertThrowsError(try viewModel.validatePassword()) { error in
			guard case CreateNewVaultPasswordViewModelError.nonMatchingPasswords = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
			XCTAssertEqual(0, self.vaultManagerMock.createdVaults.count)
		}
	}

	// MARK: Password Length

	func testCreateNewVaultWithTooShortPassword() throws {
		let vaultPath = CloudPath("/Vault")
		let account = CloudProviderAccount(accountUID: "1", cloudProviderType: .webDAV)
		let vaultUID = "12345"
		let password = "1234567"

		let viewModel = CreateNewVaultPasswordViewModel(vaultPath: vaultPath, account: account, vaultUID: vaultUID)
		viewModel.password = password
		viewModel.confirmingPassword = password
		XCTAssertThrowsError(try viewModel.validatePassword()) { error in
			guard case CreateNewVaultPasswordViewModelError.tooShortPassword = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
			XCTAssertEqual(0, self.vaultManagerMock.createdVaults.count)
		}
	}
}

private class VaultManagerMock: VaultManager {
	var createdVaults = [CreatedVault]()
	func createNewVault(withVaultUID vaultUID: String, delegateAccountUID: String, vaultPath: CloudPath, password: String, storePasswordInKeychain: Bool) -> Promise<Void> {
		let vault = CreatedVault(vaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultPath: vaultPath, password: password, storePasswordInKeychain: storePasswordInKeychain)
		createdVaults.append(vault)
		return Promise(())
	}

	func manualUnlockVault(withUID vaultUID: String, password: String) throws -> CloudProvider {
		throw MockError.notMocked
	}

	func getDecorator(forVaultUID vaultUID: String) throws -> CloudProvider {
		throw MockError.notMocked
	}

	func createFromExisting(withVaultUID vaultUID: String, delegateAccountUID: String, vaultDetails: VaultItem, password: String, storePasswordInKeychain: Bool) -> Promise<Void> {
		return Promise(MockError.notMocked)
	}

	func createLegacyFromExisting(withVaultUID vaultUID: String, delegateAccountUID: String, vaultDetails: VaultItem, password: String, storePasswordInKeychain: Bool) -> Promise<Void> {
		return Promise(MockError.notMocked)
	}

	func removeVault(withUID vaultUID: String) throws -> Promise<Void> {
		return Promise(MockError.notMocked)
	}

	func removeAllUnusedFileProviderDomains() -> Promise<Void> {
		return Promise(MockError.notMocked)
	}

	func getVaultPath(from masterkeyPath: CloudPath) -> CloudPath {
		return masterkeyPath
	}
}

private enum MockError: Error {
	case notMocked
}

private struct CreatedVault {
	let vaultUID: String
	let delegateAccountUID: String
	let vaultPath: CloudPath
	let password: String
	let storePasswordInKeychain: Bool
}
