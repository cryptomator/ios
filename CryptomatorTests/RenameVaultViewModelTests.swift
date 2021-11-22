//
//  RenameVaultViewModelTests.swift
//  CryptomatorTests
//
//  Created by Philipp Schmid on 19.10.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import CryptomatorFileProvider
import GRDB
import Promises
import XCTest
@testable import Cryptomator

class RenameVaultViewModelTests: SetVaultNameViewModelTests {
	private var maintenanceManagerMock: MaintenanceManagerMock!
	private var vaultManagerMock: VaultManagerMock!
	private var fileProviderConnectorMock: FileProviderConnectorMock!

	override func setUpWithError() throws {
		maintenanceManagerMock = MaintenanceManagerMock()
		vaultManagerMock = VaultManagerMock()
		fileProviderConnectorMock = FileProviderConnectorMock()
		let vaultAccount = VaultAccount(vaultUID: UUID().uuidString, delegateAccountUID: UUID().uuidString, vaultPath: CloudPath("/Foo/Bar"), vaultName: "Bar")
		viewModel = createViewModel(vaultAccount: vaultAccount, cloudProviderType: .webDAV)
	}

	func testRejectsVaultsInTheLocalFileSystem() throws {
		let expectation = XCTestExpectation()
		let vaultAccount = VaultAccount(vaultUID: UUID().uuidString, delegateAccountUID: UUID().uuidString, vaultPath: CloudPath("/Foo/Bar"), vaultName: "Bar")
		let viewModel = createViewModel(vaultAccount: vaultAccount, cloudProviderType: .localFileSystem)

		let newVaultName = "Baz"
		setVaultName(newVaultName, viewModel: viewModel)
		viewModel.renameVault().then {
			XCTFail("Promise fulfilled")
		}.catch { error in
			guard case RenameVaultViewModelError.vaultNotEligibleForRename = error else {
				XCTFail("Promise rejected with wrong error: \(error)")
				return
			}
			XCTAssertFalse(self.vaultManagerMock.moveVaultAccountToCalled)
			self.checkMaintenanceModeNeitherEnabledNorDisabled()
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testRejectsRootVault() throws {
		let expectation = XCTestExpectation()
		let vaultAccount = VaultAccount(vaultUID: UUID().uuidString, delegateAccountUID: UUID().uuidString, vaultPath: CloudPath("/"), vaultName: "Bar")
		let viewModel = createViewModel(vaultAccount: vaultAccount, cloudProviderType: .webDAV)

		let newVaultName = "Baz"
		setVaultName(newVaultName, viewModel: viewModel)
		viewModel.renameVault().then {
			XCTFail("Promise fulfilled")
		}.catch { error in
			guard case RenameVaultViewModelError.vaultNotEligibleForRename = error else {
				XCTFail("Promise rejected with wrong error: \(error)")
				return
			}
			XCTAssertFalse(self.vaultManagerMock.moveVaultAccountToCalled)
			self.checkMaintenanceModeNeitherEnabledNorDisabled()
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testRenameVault() throws {
		let expectation = XCTestExpectation()
		let oldVaultName = "Bar"
		let vaultAccount = VaultAccount(vaultUID: UUID().uuidString, delegateAccountUID: UUID().uuidString, vaultPath: CloudPath("/Foo/Bar"), vaultName: oldVaultName)
		let viewModel = createViewModel(vaultAccount: vaultAccount, cloudProviderType: .webDAV)
		let vaultLockingMock = VaultLockingMock()
		fileProviderConnectorMock.proxy = vaultLockingMock

		vaultManagerMock.moveVaultAccountToReturnValue = Promise(())

		XCTAssertEqual("Bar", viewModel.title)
		let newVaultName = "Baz"
		setVaultName(newVaultName, viewModel: viewModel)
		XCTAssertEqual("Bar", viewModel.title)
		viewModel.renameVault().then {
			XCTAssertEqual(1, self.vaultManagerMock.moveVaultAccountToCallsCount)
			XCTAssertEqual(CloudPath("/Foo/Baz"), self.vaultManagerMock.moveVaultAccountToReceivedArguments?.targetVaultPath)

			XCTAssertEqual(1, vaultLockingMock.lockedVaults.count)
			XCTAssertTrue(vaultLockingMock.lockedVaults.contains(NSFileProviderDomainIdentifier(vaultAccount.vaultUID)))

			self.checkMaintenanceModeEnabledThenDisabled()
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testRenameVaultWithOldNameAsSubstring() throws {
		let expectation = XCTestExpectation()
		let vaultAccount = VaultAccount(vaultUID: UUID().uuidString, delegateAccountUID: UUID().uuidString, vaultPath: CloudPath("/Foo/Bar"), vaultName: "Bar")
		let viewModel = createViewModel(vaultAccount: vaultAccount, cloudProviderType: .webDAV)
		let vaultLockingMock = VaultLockingMock()
		fileProviderConnectorMock.proxy = vaultLockingMock

		vaultManagerMock.moveVaultAccountToReturnValue = Promise(())

		let newVaultName = "Bar1"
		setVaultName(newVaultName, viewModel: viewModel)
		viewModel.renameVault().then {
			XCTAssertEqual(1, self.vaultManagerMock.moveVaultAccountToCallsCount)
			XCTAssertEqual(CloudPath("/Foo/Bar1"), self.vaultManagerMock.moveVaultAccountToReceivedArguments?.targetVaultPath)

			XCTAssertEqual(1, vaultLockingMock.lockedVaults.count)
			XCTAssertTrue(vaultLockingMock.lockedVaults.contains(NSFileProviderDomainIdentifier(vaultAccount.vaultUID)))

			self.checkMaintenanceModeEnabledThenDisabled()
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testRenameVaultWithSameName() throws {
		let expectation = XCTestExpectation()
		let vaultAccount = VaultAccount(vaultUID: UUID().uuidString, delegateAccountUID: UUID().uuidString, vaultPath: CloudPath("/Foo/Bar"), vaultName: "Bar")
		let viewModel = createViewModel(vaultAccount: vaultAccount, cloudProviderType: .webDAV)
		let vaultLockingMock = VaultLockingMock()
		fileProviderConnectorMock.proxy = vaultLockingMock

		setVaultName(vaultAccount.vaultName, viewModel: viewModel)
		viewModel.renameVault().then {
			XCTAssertFalse(self.vaultManagerMock.moveVaultAccountToCalled)
			XCTAssert(vaultLockingMock.lockedVaults.isEmpty)

			self.checkMaintenanceModeNeitherEnabledNorDisabled()
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testEnableMaintenanceModeFailed() throws {
		let expectation = XCTestExpectation()
		let vaultAccount = VaultAccount(vaultUID: UUID().uuidString, delegateAccountUID: UUID().uuidString, vaultPath: CloudPath("/Foo/Bar"), vaultName: "Bar")
		let viewModel = createViewModel(vaultAccount: vaultAccount, cloudProviderType: .webDAV)

		let newVaultName = "Baz"
		setVaultName(newVaultName, viewModel: viewModel)

		// Simulate enable maintenance mode failure
		maintenanceManagerMock.enableMaintenanceModeThrowableError = MaintenanceModeError.runningCloudTask

		viewModel.renameVault().then {
			XCTFail("Promise fulfilled")
		}.catch { error in
			guard case MaintenanceModeError.runningCloudTask = error else {
				XCTFail("Promise rejected with wrong error: \(error)")
				return
			}
			XCTAssertFalse(self.vaultManagerMock.moveVaultAccountToCalled)
			self.checkMaintenanceModeNeitherEnabledNorDisabled()
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testDisableMaintenanceModeAfterVaultMoveFailure() throws {
		let expectation = XCTestExpectation()
		let vaultAccount = VaultAccount(vaultUID: UUID().uuidString, delegateAccountUID: UUID().uuidString, vaultPath: CloudPath("/Foo/Bar"), vaultName: "Bar")
		let viewModel = createViewModel(vaultAccount: vaultAccount, cloudProviderType: .webDAV)
		let vaultLockingMock = VaultLockingMock()
		fileProviderConnectorMock.proxy = vaultLockingMock

		let newVaultName = "Baz"
		setVaultName(newVaultName, viewModel: viewModel)

		// Simulate vault move failure
		vaultManagerMock.moveVaultAccountToThrowableError = CloudProviderError.itemAlreadyExists

		viewModel.renameVault().then {
			XCTFail("Promise fulfilled")
		}.catch { error in
			guard case CloudProviderError.itemAlreadyExists = error else {
				XCTFail("Promise rejected with wrong error: \(error)")
				return
			}

			XCTAssertEqual(1, vaultLockingMock.lockedVaults.count)
			XCTAssertTrue(vaultLockingMock.lockedVaults.contains(NSFileProviderDomainIdentifier(vaultAccount.vaultUID)))

			XCTAssertFalse(self.vaultManagerMock.moveVaultAccountToCalled)
			self.checkMaintenanceModeEnabledThenDisabled()
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	private func createViewModel(vaultAccount: VaultAccount, cloudProviderType: CloudProviderType, viewControllerTitle: String? = nil) -> RenameVaultViewModel {
		let cloudProviderAccount = CloudProviderAccount(accountUID: UUID().uuidString, cloudProviderType: cloudProviderType)
		let vaultListPosition = VaultListPosition(id: 1, position: 1, vaultUID: vaultAccount.vaultUID)
		let vaultInfo = VaultInfo(vaultAccount: vaultAccount, cloudProviderAccount: cloudProviderAccount, vaultListPosition: vaultListPosition)
		return RenameVaultViewModel(provider: CloudProviderMock(), vaultInfo: vaultInfo, maintenanceManager: maintenanceManagerMock, vaultManager: vaultManagerMock, fileProviderConnector: fileProviderConnectorMock)
	}

	private func checkMaintenanceModeEnabledThenDisabled() {
		XCTAssertEqual(1, maintenanceManagerMock.enableMaintenanceModeCallsCount)
		XCTAssertEqual(1, maintenanceManagerMock.disableMaintenanceModeCallsCount)
	}

	private func checkMaintenanceModeNeitherEnabledNorDisabled() {
		XCTAssertFalse(maintenanceManagerMock.enableMaintenanceModeCalled)
		XCTAssertFalse(maintenanceManagerMock.disableMaintenanceModeCalled)
	}
}
