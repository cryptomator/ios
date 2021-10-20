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
		viewModel.vaultName = newVaultName
		viewModel.renameVault().then {
			XCTFail("Promise fulfilled")
		}.catch { error in
			guard case RenameVaultViewModelError.vaultNotElligibleForRename = error else {
				XCTFail("Promise rejected with wrong error: \(error)")
				return
			}
			XCTAssert(self.vaultManagerMock.movedVaults.isEmpty)
			XCTAssert(self.maintenanceManagerMock.maintenanceModeChanges.isEmpty)
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
		viewModel.vaultName = newVaultName
		viewModel.renameVault().then {
			XCTFail("Promise fulfilled")
		}.catch { error in
			guard case RenameVaultViewModelError.vaultNotElligibleForRename = error else {
				XCTFail("Promise rejected with wrong error: \(error)")
				return
			}
			XCTAssert(self.vaultManagerMock.movedVaults.isEmpty)
			XCTAssert(self.maintenanceManagerMock.maintenanceModeChanges.isEmpty)
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testRenameVault() throws {
		let expectation = XCTestExpectation()
		let vaultAccount = VaultAccount(vaultUID: UUID().uuidString, delegateAccountUID: UUID().uuidString, vaultPath: CloudPath("/Foo/Bar"), vaultName: "Bar")
		let viewModel = createViewModel(vaultAccount: vaultAccount, cloudProviderType: .webDAV)
		let vaultLockingMock = VaultLockingMock()
		fileProviderConnectorMock.proxy = vaultLockingMock

		let newVaultName = "Baz"
		viewModel.vaultName = newVaultName
		viewModel.renameVault().then {
			XCTAssertEqual(1, self.vaultManagerMock.movedVaults.count)
			XCTAssertEqual(CloudPath("/Foo/Baz"), self.vaultManagerMock.movedVaults[vaultAccount.vaultUID])

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

	func testEnableMaintenanceModeFailed() throws {
		let expectation = XCTestExpectation()
		let vaultAccount = VaultAccount(vaultUID: UUID().uuidString, delegateAccountUID: UUID().uuidString, vaultPath: CloudPath("/Foo/Bar"), vaultName: "Bar")
		let viewModel = createViewModel(vaultAccount: vaultAccount, cloudProviderType: .webDAV)

		let newVaultName = "Baz"
		viewModel.vaultName = newVaultName

		// Simulate enable maintenance mode failure
		maintenanceManagerMock.error = DatabaseError(resultCode: .SQLITE_CONSTRAINT_TRIGGER, message: "Running Task", sql: nil, arguments: nil)

		viewModel.renameVault().then {
			XCTFail("Promise fulfilled")
		}.catch { error in
			guard case RenameVaultViewModelError.runningCloudTask = error else {
				XCTFail("Promise rejected with wrong error: \(error)")
				return
			}
			XCTAssert(self.vaultManagerMock.movedVaults.isEmpty)
			XCTAssert(self.maintenanceManagerMock.maintenanceModeChanges.isEmpty)
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
		viewModel.vaultName = newVaultName

		// Simulate vault move failure
		let error = MockError.notMocked
		vaultManagerMock.error = error

		viewModel.renameVault().then {
			XCTFail("Promise fulfilled")
		}.catch { error in
			guard case MockError.notMocked = error else {
				XCTFail("Promise rejected with wrong error: \(error)")
				return
			}

			XCTAssertEqual(1, vaultLockingMock.lockedVaults.count)
			XCTAssertTrue(vaultLockingMock.lockedVaults.contains(NSFileProviderDomainIdentifier(vaultAccount.vaultUID)))

			XCTAssert(self.vaultManagerMock.movedVaults.isEmpty)
			self.checkMaintenanceModeEnabledThenDisabled()
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	private func createViewModel(vaultAccount: VaultAccount, cloudProviderType: CloudProviderType) -> RenameVaultViewModel {
		let cloudProviderAccount = CloudProviderAccount(accountUID: UUID().uuidString, cloudProviderType: cloudProviderType)
		let vaultListPosition = VaultListPosition(id: 1, position: 1, vaultUID: vaultAccount.vaultUID)
		let vaultInfo = VaultInfo(vaultAccount: vaultAccount, cloudProviderAccount: cloudProviderAccount, vaultListPosition: vaultListPosition)
		return RenameVaultViewModel(vaultInfo: vaultInfo, maintenanceManager: maintenanceManagerMock, vaultManager: vaultManagerMock, fileProviderConnector: fileProviderConnectorMock)
	}

	private func checkMaintenanceModeEnabledThenDisabled() {
		XCTAssertEqual(2, maintenanceManagerMock.maintenanceModeChanges.count)
		XCTAssert(maintenanceManagerMock.maintenanceModeChanges[0])
		XCTAssertFalse(maintenanceManagerMock.maintenanceModeChanges[1])
	}
}

private class MaintenanceManagerMock: MaintenanceManager {
	var maintenanceModeChanges = [Bool]()
	var error: Error?

	func enableMaintenanceMode() throws {
		if let error = error {
			throw error
		}
		maintenanceModeChanges.append(true)
	}

	func disableMaintenanceMode() throws {
		maintenanceModeChanges.append(false)
	}
}

private class VaultManagerMock: VaultManager {
	var movedVaults = [String: CloudPath]()
	var error: Error?
	func createNewVault(withVaultUID vaultUID: String, delegateAccountUID: String, vaultPath: CloudPath, password: String, storePasswordInKeychain: Bool) -> Promise<Void> {
		return Promise(MockError.notMocked)
	}

	func createFromExisting(withVaultUID vaultUID: String, delegateAccountUID: String, vaultItem: VaultItem, password: String, storePasswordInKeychain: Bool) -> Promise<Void> {
		return Promise(MockError.notMocked)
	}

	func createLegacyFromExisting(withVaultUID vaultUID: String, delegateAccountUID: String, vaultItem: VaultItem, password: String, storePasswordInKeychain: Bool) -> Promise<Void> {
		return Promise(MockError.notMocked)
	}

	func manualUnlockVault(withUID vaultUID: String, kek: [UInt8]) throws -> CloudProvider {
		throw MockError.notMocked
	}

	func removeVault(withUID vaultUID: String) throws -> Promise<Void> {
		return Promise(MockError.notMocked)
	}

	func removeAllUnusedFileProviderDomains() -> Promise<Void> {
		return Promise(MockError.notMocked)
	}

	func moveVault(account: VaultAccount, to targetVaultPath: CloudPath) -> Promise<Void> {
		if let error = error {
			return Promise(error)
		}
		movedVaults[account.vaultUID] = targetVaultPath
		return Promise(())
	}
}
