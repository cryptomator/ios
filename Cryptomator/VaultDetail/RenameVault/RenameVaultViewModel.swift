//
//  RenameVaultViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 19.10.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import CryptomatorFileProvider
import Foundation
import GRDB
import Promises

protocol RenameVaultViewModelProtcol: SetVaultNameViewModelProtocol {
	func renameVault() -> Promise<Void>
}

enum RenameVaultViewModelError: Error {
	case runningCloudTask
	case vaultNotElligibleForRename
}

class RenameVaultViewModel: SetVaultNameViewModel, RenameVaultViewModelProtcol {
	override var headerTitle: String {
		LocalizedString.getValue("addVault.createNewVault.setVaultName.header.title")
	}

	private let maintenanceManager: MaintenanceManager
	private let vaultManager: VaultManager
	private let vaultInfo: VaultInfo
	private let fileProviderConnector: FileProviderConnector

	init(vaultInfo: VaultInfo, maintenanceManager: MaintenanceManager, vaultManager: VaultManager = VaultDBManager.shared, fileProviderConnector: FileProviderConnector = FileProviderXPCConnector.shared) {
		self.vaultInfo = vaultInfo
		self.maintenanceManager = maintenanceManager
		self.vaultManager = vaultManager
		self.fileProviderConnector = fileProviderConnector
	}

	func renameVault() -> Promise<Void> {
		guard vaultElligibleForRename() else {
			return Promise(RenameVaultViewModelError.vaultNotElligibleForRename)
		}
		let newVaultName: String
		do {
			newVaultName = try getValidatedVaultName()
			try enableMaintenanceMode()
		} catch {
			return Promise(error)
		}

		return lockVault().then { () -> Promise<Void> in
			let newVaultPath = self.vaultInfo.vaultPath.deletingLastPathComponent().appendingPathComponent(newVaultName)
			return self.vaultManager.moveVault(account: self.vaultInfo.vaultAccount, to: newVaultPath)
		}.always {
			do {
				try self.maintenanceManager.disableMaintenanceMode()
			} catch {
				DDLogError("RenameVaultViewModel: Disabling Maintenance Mode failed with error: \(error)")
			}
		}
	}

	private func lockVault() -> Promise<Void> {
		let domainIdentifier = NSFileProviderDomainIdentifier(vaultInfo.vaultUID)
		let getProxyPromise: Promise<VaultLocking> = fileProviderConnector.getProxy(serviceName: VaultLockingService.name, domainIdentifier: domainIdentifier)
		return getProxyPromise.then { proxy -> Void in
			proxy.lockVault(domainIdentifier: domainIdentifier)
		}
	}

	private func vaultElligibleForRename() -> Bool {
		if vaultInfo.vaultPath == CloudPath("/") {
			return false
		}
		if vaultInfo.cloudProviderType == .localFileSystem {
			return false
		}
		return true
	}

	private func enableMaintenanceMode() throws {
		do {
			try maintenanceManager.enableMaintenanceMode()
		} catch let error as DatabaseError where error.message == "Running Task" {
			throw RenameVaultViewModelError.runningCloudTask
		}
	}
}
