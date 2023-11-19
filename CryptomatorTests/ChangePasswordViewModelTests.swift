//
//  ChangePasswordViewModelTests.swift
//  CryptomatorTests
//
//  Created by Philipp Schmid on 28.10.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Combine
import CryptomatorCloudAccessCore
import CryptomatorCryptoLib
import CryptomatorFileProvider
import Promises
import XCTest
@testable import Cryptomator
@testable import CryptomatorCommonCore
@testable import Dependencies

class ChangePasswordViewModelTests: XCTestCase {
	private var vaultManagerMock: VaultManagerMock!
	private var fileProviderConnectorMock: CryptomatorCommonCore.FileProviderConnectorMock!
	private var vaultLockingMock: VaultLockingMock!
	private var viewModel: ChangePasswordViewModel!
	private var vaultAccount: VaultAccount!
	private var maintenanceHelperMock: MaintenanceModeHelperMock!

	override func setUpWithError() throws {
		setupMocks()
		vaultAccount = VaultAccount(vaultUID: UUID().uuidString, delegateAccountUID: UUID().uuidString, vaultPath: CloudPath("/Foo/Bar"), vaultName: "Bar")
		let domain = NSFileProviderDomain(vaultUID: vaultAccount.vaultUID, displayName: vaultAccount.vaultName)
		DependencyValues.mockDependency(\.fileProviderConnector, with: fileProviderConnectorMock)
		viewModel = ChangePasswordViewModel(vaultAccount: vaultAccount, domain: domain, vaultManager: vaultManagerMock)
	}

	private func setupMocks() {
		vaultManagerMock = VaultManagerMock()
		fileProviderConnectorMock = CryptomatorCommonCore.FileProviderConnectorMock()
		maintenanceHelperMock = MaintenanceModeHelperMock()
		vaultLockingMock = VaultLockingMock()

		fileProviderConnectorMock.getXPCServiceNameDomainClosure = { serviceName, _ in
			switch serviceName {
			case .maintenanceModeHelper:
				return self.maintenanceHelperMock!
			case .vaultLocking:
				return self.vaultLockingMock!
			default:
				XCTFail("Get XPC called for unexpected serviceName: \(serviceName)")
				return Promise(MockError.notMocked)
			}
		}
	}

	func testChangePassword() async throws {
		let oldPassword = "OldPassword"
		let newPassword = "Password"
		setOldPassword(oldPassword)
		setNewPassword(newPassword)
		setNewPasswordConfirmation(newPassword)

		let maintenanceModeEnabled = XCTestExpectation()
		let maintenanceModeDisabled = XCTestExpectation()
		maintenanceHelperMock.enableMaintenanceModeReplyClosure = {
			maintenanceModeEnabled.fulfill()
			$0(nil)
		}
		maintenanceHelperMock.disableMaintenanceModeReplyClosure = {
			maintenanceModeDisabled.fulfill()
			$0(nil)
		}
		vaultManagerMock.changePassphraseOldPassphraseNewPassphraseForVaultUIDReturnValue = Promise(())

		try await viewModel.changePassword()

		await fulfillment(of: [maintenanceModeEnabled, maintenanceModeDisabled], timeout: 1.0, enforceOrder: true)

		XCTAssertEqual(1, vaultManagerMock.changePassphraseOldPassphraseNewPassphraseForVaultUIDCallsCount)
		XCTAssertEqual(oldPassword, vaultManagerMock.changePassphraseOldPassphraseNewPassphraseForVaultUIDReceivedArguments?.oldPassphrase)
		XCTAssertEqual(newPassword, vaultManagerMock.changePassphraseOldPassphraseNewPassphraseForVaultUIDReceivedArguments?.newPassphrase)
		XCTAssertEqual(vaultAccount.vaultUID, vaultManagerMock.changePassphraseOldPassphraseNewPassphraseForVaultUIDReceivedArguments?.vaultUID)

		XCTAssertEqual(1, vaultLockingMock.lockedVaults.count)
		XCTAssertTrue(vaultLockingMock.lockedVaults.contains(NSFileProviderDomainIdentifier(vaultAccount.vaultUID)))
	}

	func testEnableMaintenanceModeFailed() async throws {
		let oldPassword = "OldPassword"
		let newPassword = "Password"
		setOldPassword(oldPassword)
		setNewPassword(newPassword)
		setNewPasswordConfirmation(newPassword)

		// Simulate enable maintenance mode failure
		maintenanceHelperMock.enableMaintenanceModeReplyClosure = { $0(MaintenanceModeError.runningCloudTask as NSError) }

		await XCTAssertThrowsAsyncError(try await viewModel.changePassword()) { error in
			XCTAssertEqual(.runningCloudTask, error as? MaintenanceModeError)
		}
		XCTAssertFalse(vaultManagerMock.moveVaultAccountToCalled)
		XCTAssertFalse(maintenanceHelperMock.disableMaintenanceModeReplyCalled)
	}

	func testDisableMaintenanceModeAfterChangePassphraseFailed() async throws {
		let maintenanceModeEnabled = XCTestExpectation()
		let maintenanceModeDisabled = XCTestExpectation()
		maintenanceHelperMock.enableMaintenanceModeReplyClosure = {
			maintenanceModeEnabled.fulfill()
			$0(nil)
		}
		maintenanceHelperMock.disableMaintenanceModeReplyClosure = {
			maintenanceModeDisabled.fulfill()
			$0(nil)
		}

		// Simulate change pass phrase failure
		vaultManagerMock.changePassphraseOldPassphraseNewPassphraseForVaultUIDReturnValue = Promise(MasterkeyFileError.invalidPassphrase)

		let oldPassword = "OldPassword"
		let newPassword = "Password"
		setOldPassword(oldPassword)
		setNewPassword(newPassword)
		setNewPasswordConfirmation(newPassword)

		await XCTAssertThrowsAsyncError(try await viewModel.changePassword()) { error in
			XCTAssertEqual(.invalidOldPassword, error as? ChangePasswordViewModelError)
		}

		XCTAssertEqual(1, vaultLockingMock.lockedVaults.count)
		XCTAssertTrue(vaultLockingMock.lockedVaults.contains(NSFileProviderDomainIdentifier(vaultAccount.vaultUID)))
		await fulfillment(of: [maintenanceModeEnabled, maintenanceModeDisabled], timeout: 1.0, enforceOrder: true)
	}

	func testChangePasswordFailForEmptyOldPassword() async throws {
		setNewPassword("Password")
		setNewPasswordConfirmation("Password")
		try await checkChangePasswordFail(with: ChangePasswordViewModelError.emptyPassword)

		setOldPassword("")
		try await checkChangePasswordFail(with: ChangePasswordViewModelError.emptyPassword)
	}

	func testChangePasswordFailForEmptyNewPassword() async throws {
		setOldPassword("OldPassword")
		setNewPasswordConfirmation("Password")
		try await checkChangePasswordFail(with: ChangePasswordViewModelError.emptyPassword)

		setNewPassword("")
		try await checkChangePasswordFail(with: ChangePasswordViewModelError.emptyPassword)
	}

	func testChangePasswordFailForEmptyNewPasswordConfirmation() async throws {
		setOldPassword("OldPassword")
		setNewPassword("Password")
		try await checkChangePasswordFail(with: ChangePasswordViewModelError.emptyPassword)

		setNewPasswordConfirmation("")
		try await checkChangePasswordFail(with: ChangePasswordViewModelError.emptyPassword)
	}

	func testChangePasswordFailForNewPasswordUnderEightChars() async throws {
		setOldPassword("OldPassword")
		setNewPassword("NewPass")
		setNewPasswordConfirmation("NewPass")
		try await checkChangePasswordFail(with: ChangePasswordViewModelError.tooShortPassword)
	}

	func testChangePasswordFailForNonMatchingNewPasswordConfirmation() async throws {
		setOldPassword("OldPassword")
		setNewPassword("Password")
		setNewPasswordConfirmation("NewPassword1")
		try await checkChangePasswordFail(with: ChangePasswordViewModelError.newPasswordsDoNotMatch)
	}

	// MARK: Return Button Support

	func testReturnButtonSupport() throws {
		guard let oldPasswordViewModel = viewModel.cells[.oldPassword]?.first as? TextFieldCellViewModel else {
			XCTFail("oldPasswordViewModel not found")
			return
		}
		guard let newPasswordViewModel = viewModel.cells[.newPassword]?.first as? TextFieldCellViewModel else {
			XCTFail("newPasswordViewModel not found")
			return
		}
		guard let newPasswordConfirmationViewModel = viewModel.cells[.newPasswordConfirmation]?.first as? TextFieldCellViewModel else {
			XCTFail("newPasswordConfirmationViewModel not found")
			return
		}
		XCTAssert(oldPasswordViewModel.isInitialFirstResponder)
		XCTAssertFalse(newPasswordViewModel.isInitialFirstResponder)
		XCTAssertFalse(newPasswordConfirmationViewModel.isInitialFirstResponder)
		let lastReturnButtonPressedRecorder = viewModel.lastReturnButtonPressed.recordNext(1)

		let newPWBecomeFirstResponderRecorder = newPasswordViewModel.startListeningToBecomeFirstResponder().recordNext(1)
		let newPWConfirmationBecomeFirstResponderRecorder = newPasswordConfirmationViewModel.startListeningToBecomeFirstResponder().recordNext(1)

		oldPasswordViewModel.returnButtonPressed()
		wait(for: newPWBecomeFirstResponderRecorder)

		newPasswordViewModel.returnButtonPressed()
		wait(for: newPWConfirmationBecomeFirstResponderRecorder)
		newPasswordConfirmationViewModel.returnButtonPressed()
		wait(for: lastReturnButtonPressedRecorder)
	}

	private func checkChangePasswordFail(with expectedError: Error) async throws {
		await XCTAssertThrowsAsyncError(try await viewModel.changePassword()) { error in
			XCTAssertEqual(expectedError as NSError, error as NSError)

			XCTAssertFalse(maintenanceHelperMock.enableMaintenanceModeReplyCalled)
			XCTAssertFalse(maintenanceHelperMock.disableMaintenanceModeReplyCalled)

			XCTAssertFalse(self.vaultManagerMock.changePassphraseOldPassphraseNewPassphraseForVaultUIDCalled)

			XCTAssert(self.vaultLockingMock.lockedVaults.isEmpty)
		}
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

	private func simulateReturnButtonPressed(forFirstViewModelInSection section: ChangePasswordSection) {
		guard let passwordViewModel = viewModel.cells[section]?.first as? TextFieldCellViewModel else {
			XCTFail("ViewModel not found for section: \(section)")
			return
		}
		passwordViewModel.returnButtonPressed()
	}
}
