//
//  RenameVaultViewModelTests.swift
//  CryptomatorTests
//
//  Created by Philipp Schmid on 19.10.21.
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

class RenameVaultViewModelTests: SetVaultNameViewModelTests {
	private var vaultManagerMock: VaultManagerMock!
	private var fileProviderConnectorMock: CryptomatorCommonCore.FileProviderConnectorMock!
	private var maintenanceHelperMock: MaintenanceModeHelperMock!
	private var vaultLockingMock: VaultLockingMock!

	override func setUpWithError() throws {
		setupMocks()
		let vaultAccount = VaultAccount(vaultUID: UUID().uuidString, delegateAccountUID: UUID().uuidString, vaultPath: CloudPath("/Foo/Bar"), vaultName: "Bar")
		viewModel = createViewModel(vaultAccount: vaultAccount, cloudProviderType: .dropbox)
	}

	private func setupMocks() {
		vaultManagerMock = VaultManagerMock()
		fileProviderConnectorMock = CryptomatorCommonCore.FileProviderConnectorMock()
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

	func testRejectsVaultsInTheLocalFileSystem() async throws {
		let vaultAccount = VaultAccount(vaultUID: UUID().uuidString, delegateAccountUID: UUID().uuidString, vaultPath: CloudPath("/Foo/Bar"), vaultName: "Bar")
		let viewModel = createViewModel(vaultAccount: vaultAccount, cloudProviderType: .localFileSystem(type: .custom))

		let newVaultName = "Baz"
		setVaultName(newVaultName, viewModel: viewModel)
		await XCTAssertThrowsAsyncError(try await viewModel.renameVault()) { error in
			XCTAssertEqual(.vaultNotEligibleForRename, error as? RenameVaultViewModelError)
			XCTAssertFalse(self.vaultManagerMock.moveVaultAccountToCalled)
		}
		XCTAssertFalse(fileProviderConnectorMock.getXPCServiceNameDomainIdentifierCalled)
		XCTAssertFalse(fileProviderConnectorMock.getXPCServiceNameDomainCalled)
	}

	func testRejectsRootVault() async throws {
		let vaultAccount = VaultAccount(vaultUID: UUID().uuidString, delegateAccountUID: UUID().uuidString, vaultPath: CloudPath("/"), vaultName: "Bar")
		let viewModel = createViewModel(vaultAccount: vaultAccount, cloudProviderType: .dropbox)

		let newVaultName = "Baz"
		setVaultName(newVaultName, viewModel: viewModel)
		await XCTAssertThrowsAsyncError(try await viewModel.renameVault()) { error in
			XCTAssertEqual(.vaultNotEligibleForRename, error as? RenameVaultViewModelError)
			XCTAssertFalse(self.vaultManagerMock.moveVaultAccountToCalled)
			self.checkMaintenanceModeNeitherEnabledNorDisabled()
		}
	}

	func testRenameVault() async throws {
		let oldVaultName = "Bar"
		let vaultAccount = VaultAccount(vaultUID: UUID().uuidString, delegateAccountUID: UUID().uuidString, vaultPath: CloudPath("/Foo/Bar"), vaultName: oldVaultName)
		let viewModel = createViewModel(vaultAccount: vaultAccount, cloudProviderType: .dropbox)

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

		XCTAssertEqual("Bar", viewModel.title)
		let newVaultName = "Baz"
		setVaultName(newVaultName, viewModel: viewModel)
		XCTAssertEqual("Bar", viewModel.title)
		try await viewModel.renameVault()
		XCTAssertEqual(1, vaultManagerMock.moveVaultAccountToCallsCount)
		XCTAssertEqual(CloudPath("/Foo/Baz"), vaultManagerMock.moveVaultAccountToReceivedArguments?.targetVaultPath)

		XCTAssertEqual(1, vaultLockingMock.lockedVaults.count)
		XCTAssertTrue(vaultLockingMock.lockedVaults.contains(NSFileProviderDomainIdentifier(vaultAccount.vaultUID)))

		await fulfillment(of: [maintenanceModeEnabled, maintenanceModeDisabled], timeout: 1.0, enforceOrder: true)
	}

	func testRenameVaultWithOldNameAsSubstring() async throws {
		let vaultAccount = VaultAccount(vaultUID: UUID().uuidString, delegateAccountUID: UUID().uuidString, vaultPath: CloudPath("/Foo/Bar"), vaultName: "Bar")
		let viewModel = createViewModel(vaultAccount: vaultAccount, cloudProviderType: .dropbox)

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

		let newVaultName = "Bar1"
		setVaultName(newVaultName, viewModel: viewModel)
		try await viewModel.renameVault()
		XCTAssertEqual(1, vaultManagerMock.moveVaultAccountToCallsCount)
		XCTAssertEqual(CloudPath("/Foo/Bar1"), vaultManagerMock.moveVaultAccountToReceivedArguments?.targetVaultPath)

		XCTAssertEqual(1, vaultLockingMock.lockedVaults.count)
		XCTAssertTrue(vaultLockingMock.lockedVaults.contains(NSFileProviderDomainIdentifier(vaultAccount.vaultUID)))

		wait(for: [maintenanceModeEnabled, maintenanceModeDisabled], timeout: 1.0, enforceOrder: true)
	}

	func testRenameVaultWithSameName() async throws {
		let vaultAccount = VaultAccount(vaultUID: UUID().uuidString, delegateAccountUID: UUID().uuidString, vaultPath: CloudPath("/Foo/Bar"), vaultName: "Bar")
		let viewModel = createViewModel(vaultAccount: vaultAccount, cloudProviderType: .dropbox)

		setVaultName(vaultAccount.vaultName, viewModel: viewModel)
		try await viewModel.renameVault()
		XCTAssertFalse(vaultManagerMock.moveVaultAccountToCalled)

		XCTAssertFalse(fileProviderConnectorMock.getXPCServiceNameDomainCalled)
		XCTAssertFalse(fileProviderConnectorMock.getXPCServiceNameDomainIdentifierCalled)
	}

	func testEnableMaintenanceModeFailed() async throws {
		let vaultAccount = VaultAccount(vaultUID: UUID().uuidString, delegateAccountUID: UUID().uuidString, vaultPath: CloudPath("/Foo/Bar"), vaultName: "Bar")
		let viewModel = createViewModel(vaultAccount: vaultAccount, cloudProviderType: .dropbox)

		let newVaultName = "Baz"
		setVaultName(newVaultName, viewModel: viewModel)

		// Simulate enable maintenance mode failure
		maintenanceHelperMock.enableMaintenanceModeReplyClosure = { $0(MaintenanceModeError.runningCloudTask as NSError) }

		await XCTAssertThrowsAsyncError(try await viewModel.renameVault()) { error in
			XCTAssertEqual(.runningCloudTask, error as? MaintenanceModeError)
			XCTAssertFalse(self.vaultManagerMock.moveVaultAccountToCalled)
		}
		XCTAssert(vaultLockingMock.lockedVaults.isEmpty)
		XCTAssertFalse(vaultManagerMock.moveVaultAccountToCalled)
		XCTAssertFalse(maintenanceHelperMock.disableMaintenanceModeReplyCalled)
	}

	func testDisableMaintenanceModeAfterVaultMoveFailure() async throws {
		let vaultAccount = VaultAccount(vaultUID: UUID().uuidString, delegateAccountUID: UUID().uuidString, vaultPath: CloudPath("/Foo/Bar"), vaultName: "Bar")
		let viewModel = createViewModel(vaultAccount: vaultAccount, cloudProviderType: .dropbox)

		let newVaultName = "Baz"
		setVaultName(newVaultName, viewModel: viewModel)

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
		vaultManagerMock.moveVaultAccountToThrowableError = CloudProviderError.itemAlreadyExists

		await XCTAssertThrowsAsyncError(try await viewModel.renameVault()) { error in
			XCTAssertEqual(.itemAlreadyExists, error as? CloudProviderError)
		}
		XCTAssertEqual(1, vaultLockingMock.lockedVaults.count)
		XCTAssertTrue(vaultLockingMock.lockedVaults.contains(NSFileProviderDomainIdentifier(vaultAccount.vaultUID)))
		XCTAssertFalse(vaultManagerMock.moveVaultAccountToCalled)
		await fulfillment(of: [maintenanceModeEnabled, maintenanceModeDisabled], timeout: 1.0, enforceOrder: true)
	}

	private func createViewModel(vaultAccount: VaultAccount, cloudProviderType: CloudProviderType, viewControllerTitle: String? = nil) -> RenameVaultViewModel {
		let cloudProviderAccount = CloudProviderAccount(accountUID: UUID().uuidString, cloudProviderType: cloudProviderType)
		let vaultListPosition = VaultListPosition(id: 1, position: 1, vaultUID: vaultAccount.vaultUID)
		let vaultInfo = VaultInfo(vaultAccount: vaultAccount, cloudProviderAccount: cloudProviderAccount, vaultListPosition: vaultListPosition)
		let domain = NSFileProviderDomain(vaultUID: vaultInfo.vaultUID, displayName: vaultInfo.vaultName)
		return RenameVaultViewModel(provider: CloudProviderMock(), vaultInfo: vaultInfo, domain: domain, vaultManager: vaultManagerMock)
	}

	private func checkMaintenanceModeEnabledThenDisabled() {
//		XCTAssertEqual(1, maintenanceManagerMock.enableMaintenanceModeCallsCount)
//		XCTAssertEqual(1, maintenanceManagerMock.disableMaintenanceModeCallsCount)
	}

	private func checkMaintenanceModeNeitherEnabledNorDisabled() {
//		XCTAssertFalse(maintenanceManagerMock.enableMaintenanceModeCalled)
//		XCTAssertFalse(maintenanceManagerMock.disableMaintenanceModeCalled)
	}
}
