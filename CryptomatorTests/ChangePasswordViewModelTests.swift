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
import Dependencies
import Promises
import XCTest
@testable import Cryptomator
@testable import CryptomatorCommonCore

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
		try await withDependencies({
			$0.fileProviderConnector = fileProviderConnectorMock
		}, operation: {
			self.viewModel = self.createViewModel()
			let oldPassword = "OldPassword"
			let newPassword = "Password"
			self.setOldPassword(oldPassword)
			self.setNewPassword(newPassword)
			self.setNewPasswordConfirmation(newPassword)

			let maintenanceModeEnabled = XCTestExpectation()
			let maintenanceModeDisabled = XCTestExpectation()
			self.maintenanceHelperMock.enableMaintenanceModeReplyClosure = {
				maintenanceModeEnabled.fulfill()
				$0(nil)
			}
			self.maintenanceHelperMock.disableMaintenanceModeReplyClosure = {
				maintenanceModeDisabled.fulfill()
				$0(nil)
			}
			self.vaultManagerMock.changePassphraseOldPassphraseNewPassphraseForVaultUIDReturnValue = Promise(())

			try await self.viewModel.changePassword()

			await self.fulfillment(of: [maintenanceModeEnabled, maintenanceModeDisabled], timeout: 5.0, enforceOrder: true)

			XCTAssertEqual(1, self.vaultManagerMock.changePassphraseOldPassphraseNewPassphraseForVaultUIDCallsCount)
			XCTAssertEqual(oldPassword, self.vaultManagerMock.changePassphraseOldPassphraseNewPassphraseForVaultUIDReceivedArguments?.oldPassphrase)
			XCTAssertEqual(newPassword, self.vaultManagerMock.changePassphraseOldPassphraseNewPassphraseForVaultUIDReceivedArguments?.newPassphrase)
			XCTAssertEqual(self.vaultAccount.vaultUID, self.vaultManagerMock.changePassphraseOldPassphraseNewPassphraseForVaultUIDReceivedArguments?.vaultUID)

			XCTAssertEqual(1, self.vaultLockingMock.lockedVaults.count)
			XCTAssertTrue(self.vaultLockingMock.lockedVaults.contains(NSFileProviderDomainIdentifier(self.vaultAccount.vaultUID)))
		})
	}

	func testEnableMaintenanceModeFailed() async throws {
		try await withDependencies({
			$0.fileProviderConnector = fileProviderConnectorMock
		}, operation: {
			self.viewModel = self.createViewModel()
			let oldPassword = "OldPassword"
			let newPassword = "Password"
			self.setOldPassword(oldPassword)
			self.setNewPassword(newPassword)
			self.setNewPasswordConfirmation(newPassword)

			self.maintenanceHelperMock.enableMaintenanceModeReplyClosure = { $0(MaintenanceModeError.runningCloudTask as NSError) }

			await XCTAssertThrowsAsyncError(try await self.viewModel.changePassword()) { error in
				XCTAssertEqual(.runningCloudTask, error as? MaintenanceModeError)
			}
			XCTAssertFalse(self.vaultManagerMock.moveVaultAccountToCalled)
			XCTAssertFalse(self.maintenanceHelperMock.disableMaintenanceModeReplyCalled)
		})
	}

	func testDisableMaintenanceModeAfterChangePassphraseFailed() async throws {
		try await withDependencies({
			$0.fileProviderConnector = fileProviderConnectorMock
		}, operation: {
			self.viewModel = self.createViewModel()
			let maintenanceModeEnabled = XCTestExpectation()
			let maintenanceModeDisabled = XCTestExpectation()
			self.maintenanceHelperMock.enableMaintenanceModeReplyClosure = {
				maintenanceModeEnabled.fulfill()
				$0(nil)
			}
			self.maintenanceHelperMock.disableMaintenanceModeReplyClosure = {
				maintenanceModeDisabled.fulfill()
				$0(nil)
			}

			self.vaultManagerMock.changePassphraseOldPassphraseNewPassphraseForVaultUIDReturnValue = Promise(MasterkeyFileError.invalidPassphrase)

			let oldPassword = "OldPassword"
			let newPassword = "Password"
			self.setOldPassword(oldPassword)
			self.setNewPassword(newPassword)
			self.setNewPasswordConfirmation(newPassword)

			await XCTAssertThrowsAsyncError(try await self.viewModel.changePassword()) { error in
				XCTAssertEqual(.invalidOldPassword, error as? ChangePasswordViewModelError)
			}

			XCTAssertEqual(1, self.vaultLockingMock.lockedVaults.count)
			XCTAssertTrue(self.vaultLockingMock.lockedVaults.contains(NSFileProviderDomainIdentifier(self.vaultAccount.vaultUID)))
			await self.fulfillment(of: [maintenanceModeEnabled, maintenanceModeDisabled], timeout: 5.0, enforceOrder: true)
		})
	}

	func testChangePasswordFailForEmptyOldPassword() async throws {
		try await withDependencies({
			$0.fileProviderConnector = fileProviderConnectorMock
		}, operation: {
			self.viewModel = self.createViewModel()
			self.setNewPassword("Password")
			self.setNewPasswordConfirmation("Password")
			try await self.checkChangePasswordFail(with: ChangePasswordViewModelError.emptyPassword)

			self.setOldPassword("")
			try await self.checkChangePasswordFail(with: ChangePasswordViewModelError.emptyPassword)
		})
	}

	func testChangePasswordFailForEmptyNewPassword() async throws {
		try await withDependencies({
			$0.fileProviderConnector = fileProviderConnectorMock
		}, operation: {
			self.viewModel = self.createViewModel()
			self.setOldPassword("OldPassword")
			self.setNewPasswordConfirmation("Password")
			try await self.checkChangePasswordFail(with: ChangePasswordViewModelError.emptyPassword)

			self.setNewPassword("")
			try await self.checkChangePasswordFail(with: ChangePasswordViewModelError.emptyPassword)
		})
	}

	func testChangePasswordFailForEmptyNewPasswordConfirmation() async throws {
		try await withDependencies({
			$0.fileProviderConnector = fileProviderConnectorMock
		}, operation: {
			self.viewModel = self.createViewModel()
			self.setOldPassword("OldPassword")
			self.setNewPassword("Password")
			try await self.checkChangePasswordFail(with: ChangePasswordViewModelError.emptyPassword)

			self.setNewPasswordConfirmation("")
			try await self.checkChangePasswordFail(with: ChangePasswordViewModelError.emptyPassword)
		})
	}

	func testChangePasswordFailForNewPasswordUnderEightChars() async throws {
		try await withDependencies({
			$0.fileProviderConnector = fileProviderConnectorMock
		}, operation: {
			self.viewModel = self.createViewModel()
			self.setOldPassword("OldPassword")
			self.setNewPassword("NewPass")
			self.setNewPasswordConfirmation("NewPass")
			try await self.checkChangePasswordFail(with: ChangePasswordViewModelError.tooShortPassword)
		})
	}

	func testChangePasswordFailForNonMatchingNewPasswordConfirmation() async throws {
		try await withDependencies({
			$0.fileProviderConnector = fileProviderConnectorMock
		}, operation: {
			self.viewModel = self.createViewModel()
			self.setOldPassword("OldPassword")
			self.setNewPassword("Password")
			self.setNewPasswordConfirmation("NewPassword1")
			try await self.checkChangePasswordFail(with: ChangePasswordViewModelError.newPasswordsDoNotMatch)
		})
	}

	// MARK: Return Button Support

	func testReturnButtonSupport() {
		withDependencies {
			$0.fileProviderConnector = fileProviderConnectorMock
		} operation: {
			self.viewModel = self.createViewModel()
			guard let oldPasswordViewModel = self.viewModel.cells[.oldPassword]?.first as? TextFieldCellViewModel else {
				XCTFail("oldPasswordViewModel not found")
				return
			}
			guard let newPasswordViewModel = self.viewModel.cells[.newPassword]?.first as? TextFieldCellViewModel else {
				XCTFail("newPasswordViewModel not found")
				return
			}
			guard let newPasswordConfirmationViewModel = self.viewModel.cells[.newPasswordConfirmation]?.first as? TextFieldCellViewModel else {
				XCTFail("newPasswordConfirmationViewModel not found")
				return
			}
			XCTAssert(oldPasswordViewModel.isInitialFirstResponder)
			XCTAssertFalse(newPasswordViewModel.isInitialFirstResponder)
			XCTAssertFalse(newPasswordConfirmationViewModel.isInitialFirstResponder)
			let lastReturnButtonPressedRecorder = self.viewModel.lastReturnButtonPressed.recordNext(1)

			let newPWBecomeFirstResponderRecorder = newPasswordViewModel.startListeningToBecomeFirstResponder().recordNext(1)
			let newPWConfirmationBecomeFirstResponderRecorder = newPasswordConfirmationViewModel.startListeningToBecomeFirstResponder().recordNext(1)

			oldPasswordViewModel.returnButtonPressed()
			self.wait(for: newPWBecomeFirstResponderRecorder)

			newPasswordViewModel.returnButtonPressed()
			self.wait(for: newPWConfirmationBecomeFirstResponderRecorder)
			newPasswordConfirmationViewModel.returnButtonPressed()
			self.wait(for: lastReturnButtonPressedRecorder)
		}
	}

	private func createViewModel() -> ChangePasswordViewModel {
		let domain = NSFileProviderDomain(vaultUID: vaultAccount.vaultUID, displayName: vaultAccount.vaultName)
		return ChangePasswordViewModel(vaultAccount: vaultAccount, domain: domain, vaultManager: vaultManagerMock)
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
