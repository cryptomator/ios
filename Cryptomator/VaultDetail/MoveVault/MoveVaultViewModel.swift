//
//  MoveVaultViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 22.10.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import CryptomatorFileProvider
import FileProvider
import Foundation
import GRDB
import Promises

protocol MoveVaultViewModelProtocol: ChooseFolderViewModelProtocol {
	func moveVault() -> Promise<Void>
	func isAllowedToMove() -> Bool
}

enum MoveVaultViewModelError: Error {
	case moveVaultInsideItselfNotAllowed
	case vaultNotEligibleForMove
}

class MoveVaultViewModel: ChooseFolderViewModel, MoveVaultViewModelProtocol {
	private let maintenanceManager: MaintenanceManager
	private let vaultManager: VaultManager
	private let vaultInfo: VaultInfo
	private let fileProviderConnector: FileProviderConnector

	init(provider: CloudProvider, currentFolderChoosingCloudPath: CloudPath, vaultInfo: VaultInfo, maintenanceManager: MaintenanceManager, cloudProviderManager: CloudProviderManager = CloudProviderDBManager.shared, vaultManager: VaultManager = VaultDBManager.shared, fileProviderConnector: FileProviderConnector = FileProviderXPCConnector.shared) {
		self.vaultInfo = vaultInfo
		self.maintenanceManager = maintenanceManager
		self.vaultManager = vaultManager
		self.fileProviderConnector = fileProviderConnector
		super.init(canCreateFolder: true, cloudPath: currentFolderChoosingCloudPath, provider: provider)
	}

	func moveVault(to targetCloudPath: CloudPath) -> Promise<Void> {
		guard vaultEligibleForMove() else {
			return Promise(MoveVaultViewModelError.vaultNotEligibleForMove)
		}
		guard pathIsNotInsideCurrentVaultPath(targetCloudPath) else {
			return Promise(MoveVaultViewModelError.moveVaultInsideItselfNotAllowed)
		}
		do {
			try maintenanceManager.enableMaintenanceMode()
		} catch {
			return Promise(error)
		}
		return lockVault().then {
			return self.vaultManager.moveVault(account: self.vaultInfo.vaultAccount, to: targetCloudPath)
		}.always {
			do {
				try self.maintenanceManager.disableMaintenanceMode()
			} catch {
				DDLogError("MoveVaultViewModel: Disabling Maintenance Mode failed with error: \(error)")
			}
		}
	}

	func moveVault() -> Promise<Void> {
		let newVaultPath = super.cloudPath.appendingPathComponent(vaultInfo.vaultName)
		return moveVault(to: newVaultPath)
	}

	func isAllowedToMove() -> Bool {
		return cloudPath.appendingPathComponent(vaultInfo.vaultName) != vaultInfo.vaultPath
	}

	private func lockVault() -> Promise<Void> {
		let domainIdentifier = NSFileProviderDomainIdentifier(vaultInfo.vaultUID)
		let getProxyPromise: Promise<VaultLocking> = fileProviderConnector.getProxy(serviceName: VaultLockingService.name, domainIdentifier: domainIdentifier)
		return getProxyPromise.then { proxy -> Void in
			proxy.lockVault(domainIdentifier: domainIdentifier)
		}
	}

	private func vaultEligibleForMove() -> Bool {
		if vaultInfo.vaultPath == CloudPath("/") {
			return false
		}
		if vaultInfo.cloudProviderType == .localFileSystem {
			return false
		}
		return true
	}

	private func pathIsNotInsideCurrentVaultPath(_ path: CloudPath) -> Bool {
		return !path.contains(vaultInfo.vaultPath)
	}
}
