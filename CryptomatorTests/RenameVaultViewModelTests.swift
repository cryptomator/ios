//
//  RenameVaultViewModelTests.swift
//  CryptomatorTests
//
//  Created by Philipp Schmid on 19.10.21.
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

class RenameVaultViewModelTests: SetVaultNameViewModelTests {
	private var vaultManagerMock: VaultManagerMock!
	private var fileProviderConnectorMock: CryptomatorCommonCore.FileProviderConnectorMock!
	private var maintenanceHelperMock: MaintenanceModeHelperMock!
	private var vaultLockingMock: VaultLockingMock!

	override func setUpWithError() throws {
		setupMocks()
		withDependencies({
			$0.fileProviderConnector = fileProviderConnectorMock
		}, operation: {
			let vaultAccount = VaultAccount(vaultUID: UUID().uuidString, delegateAccountUID: UUID().uuidString, vaultPath: CloudPath("/Foo/Bar"), vaultName: "Bar")
			self.viewModel = self.createViewModel(vaultAccount: vaultAccount, cloudProviderType: .dropbox)
		})
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

	func testRejectsVaultsInTheLocalFileSystem() async throws {
		try await withDependencies({
			$0.fileProviderConnector = fileProviderConnectorMock
		}, operation: {
			let vaultAccount = VaultAccount(vaultUID: UUID().uuidString, delegateAccountUID: UUID().uuidString, vaultPath: CloudPath("/Foo/Bar"), vaultName: "Bar")
			let viewModel = self.createViewModel(vaultAccount: vaultAccount, cloudProviderType: .localFileSystem(type: .custom))

			let newVaultName = "Baz"
			self.setVaultName(newVaultName, viewModel: viewModel)
			await XCTAssertThrowsAsyncError(try await viewModel.renameVault()) { error in
				XCTAssertEqual(.vaultNotEligibleForRename, error as? RenameVaultViewModelError)
				XCTAssertFalse(self.vaultManagerMock.moveVaultAccountToCalled)
			}
			XCTAssertFalse(self.fileProviderConnectorMock.getXPCServiceNameDomainIdentifierCalled)
			XCTAssertFalse(self.fileProviderConnectorMock.getXPCServiceNameDomainCalled)
		})
	}

	func testRejectsRootVault() async throws {
		try await withDependencies({
			$0.fileProviderConnector = fileProviderConnectorMock
		}, operation: {
			let vaultAccount = VaultAccount(vaultUID: UUID().uuidString, delegateAccountUID: UUID().uuidString, vaultPath: CloudPath("/"), vaultName: "Bar")
			let viewModel = self.createViewModel(vaultAccount: vaultAccount, cloudProviderType: .dropbox)

			let newVaultName = "Baz"
			self.setVaultName(newVaultName, viewModel: viewModel)
			await XCTAssertThrowsAsyncError(try await viewModel.renameVault()) { error in
				XCTAssertEqual(.vaultNotEligibleForRename, error as? RenameVaultViewModelError)
				XCTAssertFalse(self.vaultManagerMock.moveVaultAccountToCalled)
				self.checkMaintenanceModeNeitherEnabledNorDisabled()
			}
		})
	}

	func testRenameVault() async throws {
		try await withDependencies({
			$0.fileProviderConnector = fileProviderConnectorMock
		}, operation: {
			let oldVaultName = "Bar"
			let vaultAccount = VaultAccount(vaultUID: UUID().uuidString, delegateAccountUID: UUID().uuidString, vaultPath: CloudPath("/Foo/Bar"), vaultName: oldVaultName)
			let viewModel = self.createViewModel(vaultAccount: vaultAccount, cloudProviderType: .dropbox)

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

			XCTAssertEqual("Bar", viewModel.title)
			let newVaultName = "Baz"
			self.setVaultName(newVaultName, viewModel: viewModel)
			XCTAssertEqual("Bar", viewModel.title)
			try await viewModel.renameVault()
			XCTAssertEqual(1, self.vaultManagerMock.moveVaultAccountToCallsCount)
			XCTAssertEqual(CloudPath("/Foo/Baz"), self.vaultManagerMock.moveVaultAccountToReceivedArguments?.targetVaultPath)

			XCTAssertEqual(1, self.vaultLockingMock.lockedVaults.count)
			XCTAssertTrue(self.vaultLockingMock.lockedVaults.contains(NSFileProviderDomainIdentifier(vaultAccount.vaultUID)))

			await self.fulfillment(of: [maintenanceModeEnabled, maintenanceModeDisabled], timeout: 5.0, enforceOrder: true)
		})
	}

	func testRenameVaultWithOldNameAsSubstring() async throws {
		try await withDependencies({
			$0.fileProviderConnector = fileProviderConnectorMock
		}, operation: {
			let vaultAccount = VaultAccount(vaultUID: UUID().uuidString, delegateAccountUID: UUID().uuidString, vaultPath: CloudPath("/Foo/Bar"), vaultName: "Bar")
			let viewModel = self.createViewModel(vaultAccount: vaultAccount, cloudProviderType: .dropbox)

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

			let newVaultName = "Bar1"
			self.setVaultName(newVaultName, viewModel: viewModel)
			try await viewModel.renameVault()
			XCTAssertEqual(1, self.vaultManagerMock.moveVaultAccountToCallsCount)
			XCTAssertEqual(CloudPath("/Foo/Bar1"), self.vaultManagerMock.moveVaultAccountToReceivedArguments?.targetVaultPath)

			XCTAssertEqual(1, self.vaultLockingMock.lockedVaults.count)
			XCTAssertTrue(self.vaultLockingMock.lockedVaults.contains(NSFileProviderDomainIdentifier(vaultAccount.vaultUID)))

			await self.fulfillment(of: [maintenanceModeEnabled, maintenanceModeDisabled], timeout: 5.0, enforceOrder: true)
		})
	}

	func testRenameVaultWithSameName() async throws {
		try await withDependencies({
			$0.fileProviderConnector = fileProviderConnectorMock
		}, operation: {
			let vaultAccount = VaultAccount(vaultUID: UUID().uuidString, delegateAccountUID: UUID().uuidString, vaultPath: CloudPath("/Foo/Bar"), vaultName: "Bar")
			let viewModel = self.createViewModel(vaultAccount: vaultAccount, cloudProviderType: .dropbox)

			self.setVaultName(vaultAccount.vaultName, viewModel: viewModel)
			try await viewModel.renameVault()
			XCTAssertFalse(self.vaultManagerMock.moveVaultAccountToCalled)

			XCTAssertFalse(self.fileProviderConnectorMock.getXPCServiceNameDomainCalled)
			XCTAssertFalse(self.fileProviderConnectorMock.getXPCServiceNameDomainIdentifierCalled)
		})
	}

	func testEnableMaintenanceModeFailed() async throws {
		try await withDependencies({
			$0.fileProviderConnector = fileProviderConnectorMock
		}, operation: {
			let vaultAccount = VaultAccount(vaultUID: UUID().uuidString, delegateAccountUID: UUID().uuidString, vaultPath: CloudPath("/Foo/Bar"), vaultName: "Bar")
			let viewModel = self.createViewModel(vaultAccount: vaultAccount, cloudProviderType: .dropbox)

			let newVaultName = "Baz"
			self.setVaultName(newVaultName, viewModel: viewModel)

			self.maintenanceHelperMock.enableMaintenanceModeReplyClosure = { $0(MaintenanceModeError.runningCloudTask as NSError) }

			await XCTAssertThrowsAsyncError(try await viewModel.renameVault()) { error in
				XCTAssertEqual(.runningCloudTask, error as? MaintenanceModeError)
				XCTAssertFalse(self.vaultManagerMock.moveVaultAccountToCalled)
			}
			XCTAssert(self.vaultLockingMock.lockedVaults.isEmpty)
			XCTAssertFalse(self.vaultManagerMock.moveVaultAccountToCalled)
			XCTAssertFalse(self.maintenanceHelperMock.disableMaintenanceModeReplyCalled)
		})
	}

	func testDisableMaintenanceModeAfterVaultMoveFailure() async throws {
		try await withDependencies({
			$0.fileProviderConnector = fileProviderConnectorMock
		}, operation: {
			let vaultAccount = VaultAccount(vaultUID: UUID().uuidString, delegateAccountUID: UUID().uuidString, vaultPath: CloudPath("/Foo/Bar"), vaultName: "Bar")
			let viewModel = self.createViewModel(vaultAccount: vaultAccount, cloudProviderType: .dropbox)

			let newVaultName = "Baz"
			self.setVaultName(newVaultName, viewModel: viewModel)

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

			self.vaultManagerMock.moveVaultAccountToThrowableError = CloudProviderError.itemAlreadyExists

			await XCTAssertThrowsAsyncError(try await viewModel.renameVault()) { error in
				XCTAssertEqual(.itemAlreadyExists, error as? CloudProviderError)
			}
			XCTAssertEqual(1, self.vaultLockingMock.lockedVaults.count)
			XCTAssertTrue(self.vaultLockingMock.lockedVaults.contains(NSFileProviderDomainIdentifier(vaultAccount.vaultUID)))
			XCTAssertFalse(self.vaultManagerMock.moveVaultAccountToCalled)
			await self.fulfillment(of: [maintenanceModeEnabled, maintenanceModeDisabled], timeout: 5.0, enforceOrder: true)
		})
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
