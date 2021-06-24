//
//  ChooseFolderViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 25.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjack
import CocoaLumberjackSwift
import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import Foundation

protocol ChooseFolderViewModelProtocol {
	var canCreateFolder: Bool { get }
	var cloudPath: CloudPath { get }
	var foundMasterkey: Bool { get }
	var headerTitle: String { get }
	var items: [CloudItemMetadata] { get }
	func startListenForChanges(onError: @escaping (Error) -> Void, onChange: @escaping () -> Void, onVaultDetection: @escaping (VaultDetailItem) -> Void)
	func refreshItems()
}

class ChooseFolderViewModel: ChooseFolderViewModelProtocol {
	var canCreateFolder: Bool
	var cloudPath: CloudPath
	var items = [CloudItemMetadata]()
	var foundMasterkey = false
	var headerTitle: String {
		return cloudPath.path
	}

	private let provider: CloudProvider
	private var errorListener: ((Error) -> Void)?
	private var changeListener: (() -> Void)?
	private var vaultListener: ((VaultDetailItem) -> Void)?

	init(canCreateFolder: Bool, cloudPath: CloudPath, provider: CloudProvider) {
		self.canCreateFolder = canCreateFolder
		self.cloudPath = cloudPath
		self.provider = provider
	}

	func startListenForChanges(onError: @escaping (Error) -> Void, onChange: @escaping () -> Void, onVaultDetection: @escaping (VaultDetailItem) -> Void) {
		errorListener = onError
		changeListener = onChange
		vaultListener = onVaultDetection
		refreshItems()
	}

	func refreshItems() {
		provider.fetchItemListExhaustively(forFolderAt: cloudPath).then { itemList in
			if let vaultItem = self.getVaultItem(items: itemList.items) {
				self.foundMasterkey = true
				self.vaultListener?(vaultItem)
			} else {
				self.foundMasterkey = false
				self.items = itemList.items
				self.changeListener?()
			}
		}.catch { error in
			self.errorListener?(error)
		}
	}

	func getVaultItem(items: [CloudItemMetadata]) -> VaultDetailItem? {
		if let vaultConfigPath = getVaultConfigCloudPath(items: items) {
			let vaultName = getVaultName(for: vaultConfigPath)
			return VaultDetailItem(name: vaultName, vaultPath: cloudPath, isLegacyVault: false)
		} else if let legacyMasterkeyPath = getLegacyMasterkeyPath(items: items) {
			let vaultName = getVaultName(for: legacyMasterkeyPath)
			return VaultDetailItem(name: vaultName, vaultPath: cloudPath, isLegacyVault: true)
		} else {
			return nil
		}
	}

	func getVaultConfigCloudPath(items: [CloudItemMetadata]) -> CloudPath? {
		let vaultConfigItem = items.first(where: { $0.name == "vault.cryptomator" && $0.itemType == .file })
		guard items.contains(where: { $0.name == "d" && $0.itemType == .folder }) else {
			DDLogDebug("Missing d folder")
			return nil
		}
		return vaultConfigItem?.cloudPath
	}

	func getLegacyMasterkeyPath(items: [CloudItemMetadata]) -> CloudPath? {
		let masterkeyItem = items.first(where: { $0.name == "masterkey.cryptomator" && $0.itemType == .file })
		guard items.contains(where: { $0.name == "d" && $0.itemType == .folder }) else {
			DDLogDebug("Missing d folder")
			return nil
		}
		return masterkeyItem?.cloudPath
	}

	func getVaultName(for cryptomatorFilePath: CloudPath) -> String {
		let parentPath = cryptomatorFilePath.deletingLastPathComponent()
		return parentPath.lastPathComponent
	}
}
