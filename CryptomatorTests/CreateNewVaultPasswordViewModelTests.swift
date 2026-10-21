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
import XCTest
@testable import Cryptomator

@MainActor
class CreateNewVaultPasswordViewModelTests: XCTestCase {
	private var vaultManagerMock: PasswordVaultManagerMock!
	private var viewModel: CreateNewVaultPasswordViewModel!
	private let vaultPath = CloudPath("/Vault")
	private let account = CloudProviderAccount(accountUID: "1", cloudProviderType: .dropbox)
	private let vaultUID = "12345"

	override func setUp() async throws {
		try await super.setUp()
		vaultManagerMock = PasswordVaultManagerMock()
		viewModel = CreateNewVaultPasswordViewModel(vaultPath: vaultPath, account: account, vaultUID: vaultUID, vaultManager: vaultManagerMock)
	}

	func testCreateNewVault() async throws {
		let password = "TestPassword"

		setPassword(password)
		setConfirmPassword(password)
		try await viewModel.createNewVault()
		XCTAssertEqual(1, vaultManagerMock.createdVaults.count)
		let createdVault = try XCTUnwrap(vaultManagerMock.createdVaults.first)
		XCTAssertEqual(vaultUID, createdVault.vaultUID)
		XCTAssertEqual("1", createdVault.delegateAccountUID)
		XCTAssertEqual(vaultPath, createdVault.vaultPath)
		XCTAssertEqual(password, createdVault.password)
		XCTAssertFalse(createdVault.storePasswordInKeychain)
	}

	func testCreateNewVaultWithEmptyPassword() async {
		guard let passwordCellViewModel = viewModel.sections[0].elements.first as? TextFieldCellViewModel else {
			XCTFail("No passwordCellViewModel")
			return
		}
		XCTAssert(passwordCellViewModel.input.value.isEmpty)
		await XCTAssertThrowsAsyncError(try await viewModel.createNewVault()) { error in
			guard case CreateNewVaultPasswordViewModelError.emptyPassword = error else {
				XCTFail("Threw wrong error: \(error)")
				return
			}
		}
		XCTAssertEqual(0, vaultManagerMock.createdVaults.count)
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

/// @unchecked Sendable: test double, never touched concurrently
private final class PasswordVaultManagerMock: VaultManager, @unchecked Sendable {
	var createdVaults = [CreatedVault]()

	func createNewVault(withVaultUID vaultUID: String, delegateAccountUID: String, vaultPath: CloudPath, password: String, storePasswordInKeychain: Bool) async throws {
		let vault = CreatedVault(vaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultPath: vaultPath, password: password, storePasswordInKeychain: storePasswordInKeychain)
		createdVaults.append(vault)
	}

	func getDecorator(forVaultUID vaultUID: String) throws -> CloudProvider {
		throw MockError.notMocked
	}

	func createFromExisting(withVaultUID vaultUID: String, delegateAccountUID: String, vaultItem: VaultItem, password: String, storePasswordInKeychain: Bool) async throws {
		throw MockError.notMocked
	}

	func createLegacyFromExisting(withVaultUID vaultUID: String, delegateAccountUID: String, vaultItem: VaultItem, password: String, storePasswordInKeychain: Bool) async throws {
		throw MockError.notMocked
	}

	func manualUnlockVault(withUID vaultUID: String, kek: [UInt8]) throws -> CloudProvider {
		throw MockError.notMocked
	}

	func removeVault(withUID vaultUID: String) throws -> Task<Void, Never> {
		throw MockError.notMocked
	}

	func removeVaults(withUIDs vaultUIDs: [String]) async throws {
		throw MockError.notMocked
	}

	func removeAllUnusedFileProviderDomains() async throws {
		throw MockError.notMocked
	}

	func moveVault(account: VaultAccount, to targetVaultPath: CloudPath) async throws {
		throw MockError.notMocked
	}

	func changePassphrase(oldPassphrase: String, newPassphrase: String, forVaultUID vaultUID: String) async throws {
		throw MockError.notMocked
	}

	func createVaultProvider(withUID vaultUID: String, masterkey: Masterkey) throws -> CloudProvider {
		throw MockError.notMocked
	}

	func addExistingHubVault(_ vault: ExistingHubVault) async throws {
		throw MockError.notMocked
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
