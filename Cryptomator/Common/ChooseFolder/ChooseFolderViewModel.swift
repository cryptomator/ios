//
//  ChooseFolderViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 25.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation

protocol ChooseFolderViewModelProtocol {
	var canCreateFolder: Bool { get }
	var cloudPath: CloudPath { get }
	var foundMasterkey: Bool { get }
	var items: [CloudItemMetadata] { get }
	func startListenForChanges(onError: @escaping (Error) -> Void, onChange: @escaping () -> Void, onVaultDetection: @escaping (Item) -> Void)
	func refreshItems()
}

extension ChooseFolderViewModelProtocol {
	var headerTitle: String {
		return cloudPath.path
	}
}

class ChooseFolderViewModel: ChooseFolderViewModelProtocol {
	var canCreateFolder: Bool
	var cloudPath: CloudPath
	var items = [CloudItemMetadata]()
	var foundMasterkey = false

	private let provider: CloudProvider
	private var errorListener: ((Error) -> Void)?
	private var changeListener: (() -> Void)?
	private var vaultListener: ((Item) -> Void)?

	init(canCreateFolder: Bool, cloudPath: CloudPath, provider: CloudProvider) {
		self.canCreateFolder = canCreateFolder
		self.cloudPath = cloudPath
		self.provider = provider
	}

	func startListenForChanges(onError: @escaping (Error) -> Void, onChange: @escaping () -> Void, onVaultDetection: @escaping (Item) -> Void) {
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

	func getVaultItem(items: [CloudItemMetadata]) -> Item? {
		if let vaultConfigPath = getVaultConfigCloudPath(items: items) {
			return Item(type: .vaultConfig, path: vaultConfigPath)
		} else if let legacyMasterkeyPath = getLegacyMasterkeyPath(items: items) {
			return Item(type: .legacyMasterkey, path: legacyMasterkeyPath)
		} else {
			return nil
		}
	}

	func getVaultConfigCloudPath(items: [CloudItemMetadata]) -> CloudPath? {
		let vaultConfigItem = items.first(where: { $0.name == "vault.cryptomator" && $0.itemType == .file })
		guard items.contains(where: { $0.name == "d" && $0.itemType == .folder }) else {
			print("Missing d folder")
			return nil
		}
		return vaultConfigItem?.cloudPath
	}

	func getLegacyMasterkeyPath(items: [CloudItemMetadata]) -> CloudPath? {
		let masterkeyItem = items.first(where: { $0.name == "masterkey.cryptomator" && $0.itemType == .file })
		guard items.contains(where: { $0.name == "d" && $0.itemType == .folder }) else {
			print("Missing d folder")
			return nil
		}
		return masterkeyItem?.cloudPath
	}
}
