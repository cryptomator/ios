//
//  CreateNewVaultPasswordViewModelTests.swift
//  CryptomatorTests
//
//  Created by Philipp Schmid on 18.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import CryptomatorCryptoLib
import Promises
import XCTest
@testable import Cryptomator

class CreateNewVaultPasswordViewModelTests: XCTestCase {
	private var vaultManagerMock: PasswordVaultManagerMock!
	private var viewModel: CreateNewVaultPasswordViewModel!
	private let vaultPath = CloudPath("/Vault")
	private let account = CloudProviderAccount(accountUID: "1", cloudProviderType: .dropbox)
	private let vaultUID = "12345"

	override func setUpWithError() throws {
		vaultManagerMock = PasswordVaultManagerMock()
		viewModel = CreateNewVaultPasswordViewModel(vaultPath: vaultPath, account: account, vaultUID: vaultUID)
	}

	func testCreateNewVault() throws {
		let expectation = XCTestExpectation()
		let password = "TestPassword"

		setPassword(password)
		setConfirmPassword(password)
		viewModel.createNewVault().then {
			XCTAssertEqual(1, self.vaultManagerMock.createdVaults.count)
			let createdVault = self.vaultManagerMock.createdVaults[0]
			XCTAssertEqual(self.vaultUID, createdVault.vaultUID)
			XCTAssertEqual("1", createdVault.delegateAccountUID)
			XCTAssertEqual(self.vaultPath, createdVault.vaultPath)
			XCTAssertEqual(password, createdVault.password)
			XCTAssert(createdVault.storePasswordInKeychain)
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testCreateNewVaultWithEmptyPassword() throws {
		let expectation = XCTestExpectation()

		guard let passwordCellViewModel = viewModel.sections[0].elements.first as? TextFieldCellViewModel else {
			XCTFail("No passwordCellViewModel")
			return
		}
		XCTAssert(passwordCellViewModel.input.value.isEmpty)
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
		let password = "TestPassword"

		setPassword(password)
		setConfirmPassword(password)
		try viewModel.validatePassword()
	}

	func testValidatePasswordWithEmptyConfirmingPassword() throws {
		let password = "TestPassword"

		setPassword(password)
		guard let confirmPasswordCellViewModel = viewModel.sections[1].elements.first as? TextFieldCellViewModel else {
			XCTFail("No confirmPasswordCellViewModel")
			return
		}
		XCTAssert(confirmPasswordCellViewModel.input.value.isEmpty)
		XCTAssertThrowsError(try viewModel.validatePassword()) { error in
			guard case CreateNewVaultPasswordViewModelError.nonMatchingPasswords = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
			XCTAssertEqual(0, self.vaultManagerMock.createdVaults.count)
		}
	}

	func testCreateNewVaultWithNonMatchingNonEmptyPasswords() throws {
		let password = "TestPassword"

		setPassword(password)
		setConfirmPassword("\(password)a")
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
		let password = "1234567"

		setPassword(password)
		setConfirmPassword(password)
		XCTAssertThrowsError(try viewModel.validatePassword()) { error in
			guard case CreateNewVaultPasswordViewModelError.tooShortPassword = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
			XCTAssertEqual(0, self.vaultManagerMock.createdVaults.count)
		}
	}

	private func setPassword(_ password: String) {
		guard let passwordCellViewModel = viewModel.sections[0].elements.first as? TextFieldCellViewModel else {
			XCTFail("No passwordCellViewModel")
			return
		}
		passwordCellViewModel.input.value = password
	}

	private func setConfirmPassword(_ password: String) {
		guard let confirmPasswordCellViewModel = viewModel.sections[1].elements.first as? TextFieldCellViewModel else {
			XCTFail("No confirmPasswordCellViewModel")
			return
		}
		confirmPasswordCellViewModel.input.value = password
	}
}

private class PasswordVaultManagerMock: VaultManager {
	var createdVaults = [CreatedVault]()

	func createNewVault(withVaultUID vaultUID: String, delegateAccountUID: String, vaultPath: CloudPath, password: String, storePasswordInKeychain: Bool) -> Promise<Void> {
		let vault = CreatedVault(vaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultPath: vaultPath, password: password, storePasswordInKeychain: storePasswordInKeychain)
		createdVaults.append(vault)
		return Promise(())
	}

	func getDecorator(forVaultUID vaultUID: String) throws -> CloudProvider {
		throw MockError.notMocked
	}

	func createFromExisting(withVaultUID vaultUID: String, delegateAccountUID: String, vaultItem: VaultItem, password: String, storePasswordInKeychain: Bool) -> Promise<Void> {
		return Promise(MockError.notMocked)
	}

	func createLegacyFromExisting(withVaultUID vaultUID: String, delegateAccountUID: String, vaultItem: VaultItem, password: String, storePasswordInKeychain: Bool) -> Promise<Void> {
		return Promise(MockError.notMocked)
	}

	func manualUnlockVault(withUID vaultUID: String, kek: [UInt8]) throws -> CloudProvider {
		throw MockError.notMocked
	}

	func removeVault(withUID vaultUID: String) throws -> Promise<Void> {
		return Promise(MockError.notMocked)
	}

	func removeAllUnusedFileProviderDomains() -> Promise<Void> {
		return Promise(MockError.notMocked)
	}

	func moveVault(account: VaultAccount, to targetVaultPath: CloudPath) -> Promise<Void> {
		return Promise(MockError.notMocked)
	}

	func changePassphrase(oldPassphrase: String, newPassphrase: String, forVaultUID vaultUID: String) -> Promise<Void> {
		return Promise(MockError.notMocked)
	}

	func createVaultProvider(withUID vaultUID: String, masterkey: Masterkey) throws -> CloudProvider {
		throw MockError.notMocked
	}

	func addExistingHubVault(_ vault: ExistingHubVault) -> Promise<Void> {
		return Promise(MockError.notMocked)
	}

	func manualUnlockVault(withUID vaultUID: String, rawKey: [UInt8]) throws -> CloudProvider {
		throw MockError.notMocked
	}
}

private struct CreatedVault {
	let vaultUID: String
	let delegateAccountUID: String
	let vaultPath: CloudPath
	let password: String
	let storePasswordInKeychain: Bool
}
