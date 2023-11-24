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
import Dependencies
import FileProvider
import Foundation
import GRDB
import Promises

protocol RenameVaultViewModelProtcol: SetVaultNameViewModelProtocol {
	var trimmedVaultName: String { get }
	func renameVault() async throws
}

enum RenameVaultViewModelError: Error {
	case vaultNotEligibleForRename
}

class RenameVaultViewModel: SetVaultNameViewModel, RenameVaultViewModelProtcol {
	override var title: String? {
		return vaultInfo.vaultName
	}

	// swiftlint:disable:next weak_delegate
	private let delegate: MoveVaultViewModel
	private let vaultInfo: VaultInfo
	@Dependency(\.fileProviderConnector) private var fileProviderConnector

	init(provider: CloudProvider,
	     vaultInfo: VaultInfo,
	     domain: NSFileProviderDomain,
	     vaultManager: VaultManager = VaultDBManager.shared) {
		self.delegate = MoveVaultViewModel(
			provider: provider,
			currentFolderChoosingCloudPath: CloudPath("/"),
			vaultInfo: vaultInfo,
			domain: domain,
			vaultManager: vaultManager
		)
		self.vaultInfo = vaultInfo
	}

	func renameVault() async throws {
		let newVaultName = try getValidatedVaultName()
		let newVaultPath = vaultInfo.vaultPath.deletingLastPathComponent().appendingPathComponent(newVaultName)
		do {
			try await delegate.moveVault(to: newVaultPath)
		} catch MoveVaultViewModelError.moveVaultInsideItselfNotAllowed {
			return
		} catch MoveVaultViewModelError.vaultNotEligibleForMove {
			throw RenameVaultViewModelError.vaultNotEligibleForRename
		}
	}

	override func getHeaderTitle(for section: Int) -> String? {
		guard section == 0 else {
			return nil
		}
		return LocalizedString.getValue("addVault.createNewVault.setVaultName.header.title")
	}
}
