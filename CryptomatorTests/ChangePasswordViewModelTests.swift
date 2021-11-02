//
//  ChangePasswordViewModelTests.swift
//  CryptomatorTests
//
//  Created by Philipp Schmid on 28.10.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Combine
import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import CryptomatorCryptoLib
import CryptomatorFileProvider
import Promises
import XCTest
@testable import Cryptomator

class ChangePasswordViewModelTests: XCTestCase {
	private var vaultManagerMock: VaultManagerMock!
	private var maintenanceManagerMock: MaintenanceManagerMock!
	private var fileProviderConnectorMock: FileProviderConnectorMock!
	private var vaultLockingMock: VaultLockingMock!
	private var viewModel: ChangePasswordViewModel!
	private var vaultAccount: VaultAccount!

	override func setUpWithError() throws {
		vaultManagerMock = VaultManagerMock()
		vaultManagerMock.changePassphraseOldPassphraseNewPassphraseForVaultUIDReturnValue = Promise(())
		maintenanceManagerMock = MaintenanceManagerMock()
		vaultLockingMock = VaultLockingMock()
		fileProviderConnectorMock = FileProviderConnectorMock()
		fileProviderConnectorMock.proxy = vaultLockingMock
		vaultAccount = VaultAccount(vaultUID: UUID().uuidString, delegateAccountUID: UUID().uuidString, vaultPath: CloudPath("/Foo/Bar"), vaultName: "Bar")
		viewModel = ChangePasswordViewModel(vaultAccount: vaultAccount, maintenanceManager: maintenanceManagerMock, vaultManager: vaultManagerMock, fileProviderConnector: fileProviderConnectorMock)
	}

	func testChangePassword() {
		let expectation = XCTestExpectation()
		let oldPassword = "OldPassword"
		let newPassword = "Password"
		setOldPassword(oldPassword)
		setNewPassword(newPassword)
		setNewPasswordConfirmation(newPassword)

		viewModel.changePassword().then {
			XCTAssertEqual(1, self.maintenanceManagerMock.enableMaintenanceModeCallsCount)
			XCTAssertEqual(1, self.maintenanceManagerMock.disableMaintenanceModeCallsCount)

			XCTAssertEqual(1, self.vaultManagerMock.changePassphraseOldPassphraseNewPassphraseForVaultUIDCallsCount)
			XCTAssertEqual(oldPassword, self.vaultManagerMock.changePassphraseOldPassphraseNewPassphraseForVaultUIDReceivedArguments?.oldPassphrase)
			XCTAssertEqual(newPassword, self.vaultManagerMock.changePassphraseOldPassphraseNewPassphraseForVaultUIDReceivedArguments?.newPassphrase)
			XCTAssertEqual(self.vaultAccount.vaultUID, self.vaultManagerMock.changePassphraseOldPassphraseNewPassphraseForVaultUIDReceivedArguments?.vaultUID)

			XCTAssertEqual(1, self.vaultLockingMock.lockedVaults.count)
			XCTAssertTrue(self.vaultLockingMock.lockedVaults.contains(NSFileProviderDomainIdentifier(self.vaultAccount.vaultUID)))
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testEnableMaintenanceModeFailed() throws {
		let expectation = XCTestExpectation()
		let oldPassword = "OldPassword"
		let newPassword = "Password"
		setOldPassword(oldPassword)
		setNewPassword(newPassword)
		setNewPasswordConfirmation(newPassword)

		// Simulate enable maintenance mode failure
		maintenanceManagerMock.enableMaintenanceModeThrowableError = MaintenanceModeError.runningCloudTask

		viewModel.changePassword().then {
			XCTFail("Promise fulfilled")
		}.catch { error in
			guard case MaintenanceModeError.runningCloudTask = error else {
				XCTFail("Promise rejected with wrong error: \(error)")
				return
			}
			XCTAssertFalse(self.vaultManagerMock.moveVaultAccountToCalled)
			XCTAssertFalse(self.maintenanceManagerMock.enableMaintenanceModeCalled)
			XCTAssertFalse(self.maintenanceManagerMock.disableMaintenanceModeCalled)
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testDisableMaintenanceModeAfterChangePassphraseFailed() {
		let expectation = XCTestExpectation()

		// Simulate change pass phrase failure
		vaultManagerMock.changePassphraseOldPassphraseNewPassphraseForVaultUIDReturnValue = Promise(MasterkeyFileError.invalidPassphrase)

		let oldPassword = "OldPassword"
		let newPassword = "Password"
		setOldPassword(oldPassword)
		setNewPassword(newPassword)
		setNewPasswordConfirmation(newPassword)

		viewModel.changePassword().then {
			XCTFail("Promise fulfilled")
		}.catch { error in
			XCTAssertEqual(.invalidOldPassword, error as? ChangePasswordViewModelError)
			XCTAssertEqual(1, self.maintenanceManagerMock.enableMaintenanceModeCallsCount)
			XCTAssertEqual(1, self.maintenanceManagerMock.disableMaintenanceModeCallsCount)
			XCTAssertEqual(1, self.vaultLockingMock.lockedVaults.count)
			XCTAssertTrue(self.vaultLockingMock.lockedVaults.contains(NSFileProviderDomainIdentifier(self.vaultAccount.vaultUID)))
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testChangePasswordFailForEmptyOldPassword() {
		setNewPassword("Password")
		setNewPasswordConfirmation("Password")
		checkChangePasswordFail(with: ChangePasswordViewModelError.emptyPassword)

		setOldPassword("")
		checkChangePasswordFail(with: ChangePasswordViewModelError.emptyPassword)
	}

	func testChangePasswordFailForEmptyNewPassword() {
		setOldPassword("OldPassword")
		setNewPasswordConfirmation("Password")
		checkChangePasswordFail(with: ChangePasswordViewModelError.emptyPassword)

		setNewPassword("")
		checkChangePasswordFail(with: ChangePasswordViewModelError.emptyPassword)
	}

	func testChangePasswordFailForEmptyNewPasswordConfirmation() {
		setOldPassword("OldPassword")
		setNewPassword("Password")
		checkChangePasswordFail(with: ChangePasswordViewModelError.emptyPassword)

		setNewPasswordConfirmation("")
		checkChangePasswordFail(with: ChangePasswordViewModelError.emptyPassword)
	}

	func testChangePasswordFailForNewPasswordUnderEightChars() {
		setOldPassword("OldPassword")
		setNewPassword("NewPass")
		setNewPasswordConfirmation("NewPass")
		checkChangePasswordFail(with: ChangePasswordViewModelError.tooShortPassword)
	}

	func testChangePasswordFailForNonMatchingNewPasswordConfirmation() {
		setOldPassword("OldPassword")
		setNewPassword("Password")
		setNewPasswordConfirmation("NewPassword1")
		checkChangePasswordFail(with: ChangePasswordViewModelError.newPasswordsDoNotMatch)
	}

	private func checkChangePasswordFail(with expectedError: Error) {
		let expectation = XCTestExpectation()
		viewModel.changePassword().then {
			XCTFail("Promise fulfilled")
		}.catch { error in
			XCTAssertEqual(expectedError as NSError, error as NSError)

			XCTAssertFalse(self.maintenanceManagerMock.enableMaintenanceModeCalled)
			XCTAssertFalse(self.maintenanceManagerMock.disableMaintenanceModeCalled)

			XCTAssertFalse(self.vaultManagerMock.changePassphraseOldPassphraseNewPassphraseForVaultUIDCalled)

			XCTAssert(self.vaultLockingMock.lockedVaults.isEmpty)
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	private func setOldPassword(_ password: String) {
		setPassword(password, section: .oldPassword)
	}

	private func setNewPassword(_ password: String) {
		setPassword(password, section: .newPassword)
	}

	private func setNewPasswordConfirmation(_ password: String) {
		setPassword(password, section: .newPasswordConfirmation)
	}

	private func setPassword(_ password: String, section: ChangePasswordSection) {
		guard let passwordViewModel = viewModel.cells[section]?.first as? TextFieldCellViewModel else {
			XCTFail("ViewModel not found for section: \(section)")
			return
		}
		passwordViewModel.input.value = password
	}
}
