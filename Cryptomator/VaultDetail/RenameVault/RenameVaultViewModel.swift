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
	case vaultNotEligibleForRename
}

class RenameVaultViewModel: SetVaultNameViewModel, RenameVaultViewModelProtcol {
	override var headerTitle: String {
		LocalizedString.getValue("addVault.createNewVault.setVaultName.header.title")
	}

	// swiftlint:disable:next weak_delegate
	private let delegate: MoveVaultViewModel
	private let vaultInfo: VaultInfo

	init(provider: CloudProvider, vaultInfo: VaultInfo, maintenanceManager: MaintenanceManager, vaultManager: VaultManager = VaultDBManager.shared, fileProviderConnector: FileProviderConnector = FileProviderXPCConnector.shared) {
		self.delegate = MoveVaultViewModel(provider: provider, currentFolderChoosingCloudPath: CloudPath("/"), vaultInfo: vaultInfo, maintenanceManager: maintenanceManager, vaultManager: vaultManager, fileProviderConnector: fileProviderConnector)
		self.vaultInfo = vaultInfo
	}

	func renameVault() -> Promise<Void> {
		let newVaultName: String
		do {
			newVaultName = try getValidatedVaultName()
		} catch {
			return Promise(error)
		}
		let newVaultPath = vaultInfo.vaultPath.deletingLastPathComponent().appendingPathComponent(newVaultName)
		return delegate.moveVault(to: newVaultPath).recover { error -> Void in
			guard let moveVaultViewModelError = error as? MoveVaultViewModelError else {
				throw error
			}
			switch moveVaultViewModelError {
			case .vaultNotEligibleForMove:
				throw RenameVaultViewModelError.vaultNotEligibleForRename
			case .moveVaultInsideItselfNotAllowed:
				return
			}
		}
	}
}
