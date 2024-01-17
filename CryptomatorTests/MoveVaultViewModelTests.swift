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
@testable import Dependencies

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
		viewModel = createViewModel(currentFolderChoosingCloudPath: CloudPath("/"), vaultAccount: vaultAccount, cloudProviderType: .dropbox)
	}

	private func setupMocks() {
		vaultManagerMock = VaultManagerMock()
		fileProviderConnectorMock = CryptomatorCommonCore.FileProviderConnectorMock()
		cloudProviderMock = CloudProviderMock()
		maintenanceHelperMock = MaintenanceModeHelperMock()
		vaultLockingMock = VaultLockingMock()

		DependencyValues.mockDependency(\.fileProviderConnector, with: fileProviderConnectorMock)

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
		let targetCloudPath = CloudPath("Baz")
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

		vaultManagerMock.moveVaultAccountToReturnValue = Promise(())

		try await viewModel.moveVault(to: targetCloudPath)
		XCTAssertEqual(1, vaultManagerMock.moveVaultAccountToCallsCount)
		XCTAssertEqual(targetCloudPath, vaultManagerMock.moveVaultAccountToReceivedArguments?.targetVaultPath)

		XCTAssertEqual(1, vaultLockingMock.lockedVaults.count)
		XCTAssertTrue(vaultLockingMock.lockedVaults.contains(NSFileProviderDomainIdentifier(vaultAccount.vaultUID)))

		await fulfillment(of: [maintenanceModeEnabled, maintenanceModeDisabled], timeout: 1.0, enforceOrder: true)
	}

	func testRejectVaultsInTheLocalFileSystem() async throws {
		let vaultAccount = VaultAccount(vaultUID: UUID().uuidString, delegateAccountUID: UUID().uuidString, vaultPath: CloudPath("/Foo/Bar"), vaultName: "Bar")
		let viewModel = createViewModel(currentFolderChoosingCloudPath: CloudPath("/"), vaultAccount: vaultAccount, cloudProviderType: .localFileSystem(type: .custom))
		await XCTAssertThrowsAsyncError(try await viewModel.moveVault(to: CloudPath("Baz")), "") { error in
			XCTAssertEqual(.vaultNotEligibleForMove, error as? MoveVaultViewModelError)

			XCTAssertFalse(self.vaultManagerMock.moveVaultAccountToCalled)
			XCTAssertFalse(fileProviderConnectorMock.getXPCServiceNameDomainCalled)
			XCTAssertFalse(fileProviderConnectorMock.getXPCServiceNameDomainIdentifierCalled)
		}
	}

	func testRejectMoveRootVault() async throws {
		let vaultAccount = VaultAccount(vaultUID: UUID().uuidString, delegateAccountUID: UUID().uuidString, vaultPath: CloudPath("/"), vaultName: "Foo")
		let viewModel = createViewModel(currentFolderChoosingCloudPath: CloudPath("/"), vaultAccount: vaultAccount, cloudProviderType: .dropbox)
		await XCTAssertThrowsAsyncError(try await viewModel.moveVault(to: CloudPath("Bar")), "") { error in
			XCTAssertEqual(.vaultNotEligibleForMove, error as? MoveVaultViewModelError)

			XCTAssertFalse(self.vaultManagerMock.moveVaultAccountToCalled)
			XCTAssertFalse(fileProviderConnectorMock.getXPCServiceNameDomainCalled)
			XCTAssertFalse(fileProviderConnectorMock.getXPCServiceNameDomainIdentifierCalled)
		}
	}

	func testRejectMoveVaultIntoItself() async throws {
		let targetCloudPath = vaultAccount.vaultPath.appendingPathComponent("Test")
		await XCTAssertThrowsAsyncError(try await viewModel.moveVault(to: targetCloudPath), "") { error in
			XCTAssertEqual(.moveVaultInsideItselfNotAllowed, error as? MoveVaultViewModelError)

			XCTAssertFalse(self.vaultManagerMock.moveVaultAccountToCalled)
			XCTAssertFalse(fileProviderConnectorMock.getXPCServiceNameDomainCalled)
			XCTAssertFalse(fileProviderConnectorMock.getXPCServiceNameDomainIdentifierCalled)
		}
	}

	func testEnableMaintenanceModeFailed() async throws {
		// Simulate enable maintenance mode failure
		maintenanceHelperMock.enableMaintenanceModeReplyClosure = { $0(MaintenanceModeError.runningCloudTask as NSError) }

		await XCTAssertThrowsAsyncError(try await viewModel.moveVault(to: CloudPath("/Test")), "") { error in
			XCTAssertEqual(.runningCloudTask, error as? MaintenanceModeError)

			XCTAssertFalse(vaultManagerMock.moveVaultAccountToCalled)
			XCTAssertEqual(1, maintenanceHelperMock.enableMaintenanceModeReplyCallsCount)
			XCTAssertFalse(maintenanceHelperMock.disableMaintenanceModeReplyCalled)
		}
	}

	func testDisableMaintenanceModeAfterVaultMoveFailure() async throws {
		let vaultAccount = VaultAccount(vaultUID: UUID().uuidString, delegateAccountUID: UUID().uuidString, vaultPath: CloudPath("/Foo/Bar"), vaultName: "Bar")
		let viewModel = createViewModel(currentFolderChoosingCloudPath: CloudPath("/"), vaultAccount: vaultAccount, cloudProviderType: .dropbox)

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
		// Simulate vault move failure
		vaultManagerMock.moveVaultAccountToReturnValue = Promise(CloudProviderError.itemAlreadyExists)

		await XCTAssertThrowsAsyncError(try await viewModel.moveVault(to: CloudPath("/Test")), "") { error in
			XCTAssertEqual(.itemAlreadyExists, error as? CloudProviderError)

			XCTAssertEqual(1, vaultLockingMock.lockedVaults.count)
			XCTAssertTrue(vaultLockingMock.lockedVaults.contains(NSFileProviderDomainIdentifier(vaultAccount.vaultUID)))

			XCTAssertEqual(1, self.vaultManagerMock.moveVaultAccountToCallsCount)
		}

		wait(for: [maintenanceModeEnabled, maintenanceModeDisabled], timeout: 1.0, enforceOrder: true)
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
		let domain = NSFileProviderDomain(vaultUID: vaultInfo.vaultUID, displayName: vaultInfo.vaultName)
		return MoveVaultViewModel(provider: cloudProviderMock,
		                          currentFolderChoosingCloudPath: currentFolderChoosingCloudPath,
		                          vaultInfo: vaultInfo,
		                          domain: domain,
		                          vaultManager: vaultManagerMock)
	}
}
