//
//  MoveVaultViewModelTests.swift
//  CryptomatorTests
//
//  Created by Philipp Schmid on 25.10.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorFileProvider
import GRDB
import Promises
import XCTest
@testable import Cryptomator
@testable import CryptomatorCommonCore

class MoveVaultViewModelTests: XCTestCase {
	private var maintenanceManagerMock: MaintenanceManagerMock!
	private var vaultManagerMock: VaultManagerMock!
	private var fileProviderConnectorMock: FileProviderConnectorMock!
	private var cloudProviderMock: CloudProviderMock!
	var viewModel: MoveVaultViewModel!
	var vaultAccount: VaultAccount!

	override func setUpWithError() throws {
		maintenanceManagerMock = MaintenanceManagerMock()
		vaultManagerMock = VaultManagerMock()
		fileProviderConnectorMock = FileProviderConnectorMock()
		cloudProviderMock = CloudProviderMock()
		vaultAccount = VaultAccount(vaultUID: UUID().uuidString, delegateAccountUID: UUID().uuidString, vaultPath: CloudPath("/Foo/Bar"), vaultName: "Bar")
		viewModel = createViewModel(currentFolderChoosingCloudPath: CloudPath("/"), vaultAccount: vaultAccount, cloudProviderType: .dropbox)
	}

	func testMoveVault() throws {
		let expectation = XCTestExpectation()
		let targetCloudPath = CloudPath("Baz")
		let vaultLockingMock = VaultLockingMock()
		fileProviderConnectorMock.proxy = vaultLockingMock
		vaultManagerMock.moveVaultAccountToReturnValue = Promise(())

		viewModel.moveVault(to: targetCloudPath).then {
			XCTAssertEqual(1, self.vaultManagerMock.moveVaultAccountToCallsCount)
			XCTAssertEqual(targetCloudPath, self.vaultManagerMock.moveVaultAccountToReceivedArguments?.targetVaultPath)

			XCTAssertEqual(1, vaultLockingMock.lockedVaults.count)
			XCTAssertTrue(vaultLockingMock.lockedVaults.contains(NSFileProviderDomainIdentifier(self.vaultAccount.vaultUID)))

			XCTAssertEqual(1, self.maintenanceManagerMock.enableMaintenanceModeCallsCount)
			XCTAssertEqual(1, self.maintenanceManagerMock.disableMaintenanceModeCallsCount)
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
		XCTAssertEqual(1, fileProviderConnectorMock.xpcInvalidationCallCount)
	}

	func testRejectVaultsInTheLocalFileSystem() throws {
		let expectation = XCTestExpectation()
		let vaultAccount = VaultAccount(vaultUID: UUID().uuidString, delegateAccountUID: UUID().uuidString, vaultPath: CloudPath("/Foo/Bar"), vaultName: "Bar")
		let viewModel = createViewModel(currentFolderChoosingCloudPath: CloudPath("/"), vaultAccount: vaultAccount, cloudProviderType: .localFileSystem(type: .custom))
		viewModel.moveVault(to: CloudPath("Baz")).then {
			XCTFail("Promise fulfilled")
		}.catch { error in
			guard case MoveVaultViewModelError.vaultNotEligibleForMove = error else {
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

	func testRejectMoveRootVault() throws {
		let expectation = XCTestExpectation()
		let vaultAccount = VaultAccount(vaultUID: UUID().uuidString, delegateAccountUID: UUID().uuidString, vaultPath: CloudPath("/"), vaultName: "Foo")
		let viewModel = createViewModel(currentFolderChoosingCloudPath: CloudPath("/"), vaultAccount: vaultAccount, cloudProviderType: .dropbox)
		viewModel.moveVault(to: CloudPath("/Bar")).then {
			XCTFail("Promise fulfilled")
		}.catch { error in
			guard case MoveVaultViewModelError.vaultNotEligibleForMove = error else {
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

	func testRejectMoveVaultIntoItself() throws {
		let expectation = XCTestExpectation()
		let targetCloudPath = vaultAccount.vaultPath.appendingPathComponent("Test")
		viewModel.moveVault(to: targetCloudPath).then {
			XCTFail("Promise fulfilled")
		}.catch { error in
			guard case MoveVaultViewModelError.moveVaultInsideItselfNotAllowed = error else {
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

	func testEnableMaintenanceModeFailed() throws {
		let expectation = XCTestExpectation()

		// Simulate enable maintenance mode failure
		maintenanceManagerMock.enableMaintenanceModeThrowableError = MaintenanceModeError.runningCloudTask

		viewModel.moveVault(to: CloudPath("/Test")).then {
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

	func testDisableMaintenanceModeAfterVaultMoveFailure() throws {
		let expectation = XCTestExpectation()
		let vaultAccount = VaultAccount(vaultUID: UUID().uuidString, delegateAccountUID: UUID().uuidString, vaultPath: CloudPath("/Foo/Bar"), vaultName: "Bar")
		let viewModel = createViewModel(currentFolderChoosingCloudPath: CloudPath("/"), vaultAccount: vaultAccount, cloudProviderType: .dropbox)
		let vaultLockingMock = VaultLockingMock()
		fileProviderConnectorMock.proxy = vaultLockingMock

		// Simulate vault move failure
		vaultManagerMock.moveVaultAccountToReturnValue = Promise(CloudProviderError.itemAlreadyExists)

		viewModel.moveVault(to: CloudPath("/Test")).then {
			XCTFail("Promise fulfilled")
		}.catch { error in
			guard case CloudProviderError.itemAlreadyExists = error else {
				XCTFail("Promise rejected with wrong error: \(error)")
				return
			}

			XCTAssertEqual(1, vaultLockingMock.lockedVaults.count)
			XCTAssertTrue(vaultLockingMock.lockedVaults.contains(NSFileProviderDomainIdentifier(vaultAccount.vaultUID)))

			XCTAssertEqual(1, self.vaultManagerMock.moveVaultAccountToCallsCount)
			XCTAssertEqual(1, self.maintenanceManagerMock.enableMaintenanceModeCallsCount)
			XCTAssertEqual(1, self.maintenanceManagerMock.disableMaintenanceModeCallsCount)
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
		XCTAssertEqual(1, fileProviderConnectorMock.xpcInvalidationCallCount)
	}

	func testIsAllowedToMove() throws {
		let moveVaultViewModel = createViewModel(currentFolderChoosingCloudPath: CloudPath("/Test"), vaultAccount: vaultAccount, cloudProviderType: .dropbox)
		XCTAssert(moveVaultViewModel.isAllowedToMove())

		// allowed to move for root path
		let rootMoveVaultViewModel = createViewModel(currentFolderChoosingCloudPath: CloudPath("/"), vaultAccount: vaultAccount, cloudProviderType: .dropbox)
		XCTAssert(rootMoveVaultViewModel.isAllowedToMove())

		// not allowed to move for same location
		let sameLocationMoveVaultViewModel = createViewModel(currentFolderChoosingCloudPath: CloudPath("/Foo"), vaultAccount: vaultAccount, cloudProviderType: .dropbox)
		XCTAssertFalse(sameLocationMoveVaultViewModel.isAllowedToMove())
	}

	private func createViewModel(currentFolderChoosingCloudPath: CloudPath, vaultAccount: VaultAccount, cloudProviderType: CloudProviderType) -> MoveVaultViewModel {
		let cloudProviderAccount = CloudProviderAccount(accountUID: UUID().uuidString, cloudProviderType: cloudProviderType)
		let vaultListPosition = VaultListPosition(id: 1, position: 1, vaultUID: vaultAccount.vaultUID)
		let vaultInfo = VaultInfo(vaultAccount: vaultAccount, cloudProviderAccount: cloudProviderAccount, vaultListPosition: vaultListPosition)
		return MoveVaultViewModel(provider: cloudProviderMock, currentFolderChoosingCloudPath: currentFolderChoosingCloudPath, vaultInfo: vaultInfo, maintenanceManager: maintenanceManagerMock, vaultManager: vaultManagerMock, fileProviderConnector: fileProviderConnectorMock)
	}
}
