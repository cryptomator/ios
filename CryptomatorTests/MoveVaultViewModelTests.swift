//
//  MoveVaultViewModelTests.swift
//  CryptomatorTests
//
//  Created by Philipp Schmid on 25.10.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorFileProvider
import Dependencies
import GRDB
import Promises
import XCTest
@testable import Cryptomator
@testable import CryptomatorCommonCore

class MoveVaultViewModelTests: XCTestCase {
	private var vaultManagerMock: VaultManagerMock!
	private var fileProviderConnectorMock: CryptomatorCommonCore.FileProviderConnectorMock!
	private var cloudProviderMock: CloudProviderMock!
	var viewModel: MoveVaultViewModel!
	var vaultAccount: VaultAccount!
	private var maintenanceHelperMock: MaintenanceModeHelperMock!
	private var vaultLockingMock: VaultLockingMock!

	override func setUpWithError() throws {
		setupMocks()
		vaultAccount = VaultAccount(vaultUID: UUID().uuidString, delegateAccountUID: UUID().uuidString, vaultPath: CloudPath("/Foo/Bar"), vaultName: "Bar")
	}

	private func setupMocks() {
		vaultManagerMock = VaultManagerMock()
		fileProviderConnectorMock = CryptomatorCommonCore.FileProviderConnectorMock()
		cloudProviderMock = CloudProviderMock()
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

	func testMoveVault() async throws {
		try await withDependencies({
			$0.fileProviderConnector = fileProviderConnectorMock
		}, operation: {
			self.viewModel = self.createViewModel(currentFolderChoosingCloudPath: CloudPath("/"), vaultAccount: self.vaultAccount, cloudProviderType: .dropbox)
			let targetCloudPath = CloudPath("Baz")
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

			self.vaultManagerMock.moveVaultAccountToReturnValue = Promise(())

			try await self.viewModel.moveVault(to: targetCloudPath)
			XCTAssertEqual(1, self.vaultManagerMock.moveVaultAccountToCallsCount)
			XCTAssertEqual(targetCloudPath, self.vaultManagerMock.moveVaultAccountToReceivedArguments?.targetVaultPath)

			XCTAssertEqual(1, self.vaultLockingMock.lockedVaults.count)
			XCTAssertTrue(self.vaultLockingMock.lockedVaults.contains(NSFileProviderDomainIdentifier(self.vaultAccount.vaultUID)))

			await self.fulfillment(of: [maintenanceModeEnabled, maintenanceModeDisabled], timeout: 5.0, enforceOrder: true)
		})
	}

	func testRejectVaultsInTheLocalFileSystem() async throws {
		try await withDependencies({
			$0.fileProviderConnector = fileProviderConnectorMock
		}, operation: {
			let vaultAccount = VaultAccount(vaultUID: UUID().uuidString, delegateAccountUID: UUID().uuidString, vaultPath: CloudPath("/Foo/Bar"), vaultName: "Bar")
			let viewModel = self.createViewModel(currentFolderChoosingCloudPath: CloudPath("/"), vaultAccount: vaultAccount, cloudProviderType: .localFileSystem(type: .custom))
			await XCTAssertThrowsAsyncError(try await viewModel.moveVault(to: CloudPath("Baz")), "") { error in
				XCTAssertEqual(.vaultNotEligibleForMove, error as? MoveVaultViewModelError)

				XCTAssertFalse(self.vaultManagerMock.moveVaultAccountToCalled)
				XCTAssertFalse(self.fileProviderConnectorMock.getXPCServiceNameDomainCalled)
				XCTAssertFalse(self.fileProviderConnectorMock.getXPCServiceNameDomainIdentifierCalled)
			}
		})
	}

	func testRejectMoveRootVault() async throws {
		try await withDependencies({
			$0.fileProviderConnector = fileProviderConnectorMock
		}, operation: {
			let vaultAccount = VaultAccount(vaultUID: UUID().uuidString, delegateAccountUID: UUID().uuidString, vaultPath: CloudPath("/"), vaultName: "Foo")
			let viewModel = self.createViewModel(currentFolderChoosingCloudPath: CloudPath("/"), vaultAccount: vaultAccount, cloudProviderType: .dropbox)
			await XCTAssertThrowsAsyncError(try await viewModel.moveVault(to: CloudPath("Bar")), "") { error in
				XCTAssertEqual(.vaultNotEligibleForMove, error as? MoveVaultViewModelError)

				XCTAssertFalse(self.vaultManagerMock.moveVaultAccountToCalled)
				XCTAssertFalse(self.fileProviderConnectorMock.getXPCServiceNameDomainCalled)
				XCTAssertFalse(self.fileProviderConnectorMock.getXPCServiceNameDomainIdentifierCalled)
			}
		})
	}

	func testRejectMoveVaultIntoItself() async throws {
		try await withDependencies({
			$0.fileProviderConnector = fileProviderConnectorMock
		}, operation: {
			self.viewModel = self.createViewModel(currentFolderChoosingCloudPath: CloudPath("/"), vaultAccount: self.vaultAccount, cloudProviderType: .dropbox)
			let targetCloudPath = self.vaultAccount.vaultPath.appendingPathComponent("Test")
			await XCTAssertThrowsAsyncError(try await self.viewModel.moveVault(to: targetCloudPath), "") { error in
				XCTAssertEqual(.moveVaultInsideItselfNotAllowed, error as? MoveVaultViewModelError)

				XCTAssertFalse(self.vaultManagerMock.moveVaultAccountToCalled)
				XCTAssertFalse(self.fileProviderConnectorMock.getXPCServiceNameDomainCalled)
				XCTAssertFalse(self.fileProviderConnectorMock.getXPCServiceNameDomainIdentifierCalled)
			}
		})
	}

	func testEnableMaintenanceModeFailed() async throws {
		try await withDependencies({
			$0.fileProviderConnector = fileProviderConnectorMock
		}, operation: {
			self.viewModel = self.createViewModel(currentFolderChoosingCloudPath: CloudPath("/"), vaultAccount: self.vaultAccount, cloudProviderType: .dropbox)
			self.maintenanceHelperMock.enableMaintenanceModeReplyClosure = { $0(MaintenanceModeError.runningCloudTask as NSError) }

			await XCTAssertThrowsAsyncError(try await self.viewModel.moveVault(to: CloudPath("/Test")), "") { error in
				XCTAssertEqual(.runningCloudTask, error as? MaintenanceModeError)

				XCTAssertFalse(self.vaultManagerMock.moveVaultAccountToCalled)
				XCTAssertEqual(1, self.maintenanceHelperMock.enableMaintenanceModeReplyCallsCount)
				XCTAssertFalse(self.maintenanceHelperMock.disableMaintenanceModeReplyCalled)
			}
		})
	}

	func testDisableMaintenanceModeAfterVaultMoveFailure() async throws {
		try await withDependencies({
			$0.fileProviderConnector = fileProviderConnectorMock
		}, operation: {
			let vaultAccount = VaultAccount(vaultUID: UUID().uuidString, delegateAccountUID: UUID().uuidString, vaultPath: CloudPath("/Foo/Bar"), vaultName: "Bar")
			let viewModel = self.createViewModel(currentFolderChoosingCloudPath: CloudPath("/"), vaultAccount: vaultAccount, cloudProviderType: .dropbox)

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
			self.vaultManagerMock.moveVaultAccountToReturnValue = Promise(CloudProviderError.itemAlreadyExists)

			await XCTAssertThrowsAsyncError(try await viewModel.moveVault(to: CloudPath("/Test")), "") { error in
				XCTAssertEqual(.itemAlreadyExists, error as? CloudProviderError)

				XCTAssertEqual(1, self.vaultLockingMock.lockedVaults.count)
				XCTAssertTrue(self.vaultLockingMock.lockedVaults.contains(NSFileProviderDomainIdentifier(vaultAccount.vaultUID)))

				XCTAssertEqual(1, self.vaultManagerMock.moveVaultAccountToCallsCount)
			}

			await self.fulfillment(of: [maintenanceModeEnabled, maintenanceModeDisabled], timeout: 5.0, enforceOrder: true)
		})
	}

	func testIsAllowedToMove() {
		withDependencies {
			$0.fileProviderConnector = fileProviderConnectorMock
		} operation: {
			let moveVaultViewModel = self.createViewModel(currentFolderChoosingCloudPath: CloudPath("/Test"), vaultAccount: self.vaultAccount, cloudProviderType: .dropbox)
			XCTAssert(moveVaultViewModel.isAllowedToMove())

			let rootMoveVaultViewModel = self.createViewModel(currentFolderChoosingCloudPath: CloudPath("/"), vaultAccount: self.vaultAccount, cloudProviderType: .dropbox)
			XCTAssert(rootMoveVaultViewModel.isAllowedToMove())

			let sameLocationMoveVaultViewModel = self.createViewModel(currentFolderChoosingCloudPath: CloudPath("/Foo"), vaultAccount: self.vaultAccount, cloudProviderType: .dropbox)
			XCTAssertFalse(sameLocationMoveVaultViewModel.isAllowedToMove())
		}
	}

	private func createViewModel(currentFolderChoosingCloudPath: CloudPath, vaultAccount: VaultAccount, cloudProviderType: CloudProviderType) -> MoveVaultViewModel {
		let cloudProviderAccount = CloudProviderAccount(accountUID: UUID().uuidString, cloudProviderType: cloudProviderType)
		let vaultListPosition = VaultListPosition(id: 1, position: 1, vaultUID: vaultAccount.vaultUID)
		let vaultInfo = VaultInfo(vaultAccount: vaultAccount, cloudProviderAccount: cloudProviderAccount, vaultListPosition: vaultListPosition)
		let domain = NSFileProviderDomain(vaultUID: vaultInfo.vaultUID, displayName: vaultInfo.vaultName)
		return MoveVaultViewModel(provider: cloudProviderMock,
		                          currentFolderChoosingCloudPath: currentFolderChoosingCloudPath,
		                          vaultInfo: vaultInfo,
		                          domain: domain,
		                          vaultManager: vaultManagerMock)
	}
}
