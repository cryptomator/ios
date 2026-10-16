//
//  ChooseFolderViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 25.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import Foundation

protocol ChooseFolderViewModelProtocol: AnyObject {
	var canCreateFolder: Bool { get }
	var cloudPath: CloudPath { get }
	var foundMasterkey: Bool { get }
	var headerTitle: String { get }
	var items: [CloudItemMetadata] { get }
	func startListenForChanges(onError: @escaping (Error) -> Void, onChange: @escaping () -> Void, onVaultDetection: @escaping (VaultDetailItem) -> Void)
	func refreshItems()
	func addItem(_ item: CloudItemMetadata)
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
		self.provider = LocalizedCloudProviderDecorator(delegate: provider)
	}

	func startListenForChanges(onError: @escaping (Error) -> Void, onChange: @escaping () -> Void, onVaultDetection: @escaping (VaultDetailItem) -> Void) {
		errorListener = onError
		changeListener = onChange
		vaultListener = onVaultDetection
		refreshItems()
	}

	func refreshItems() {
		Task {
			do {
				let itemList = try await provider.fetchItemListExhaustively(forFolderAt: cloudPath)
				if let vaultItem = VaultDetector.getVaultItem(items: itemList.items, parentCloudPath: cloudPath) {
					foundMasterkey = true
					vaultListener?(vaultItem)
				} else {
					foundMasterkey = false
					items = itemList.items.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
					changeListener?()
				}
			} catch {
				errorListener?(error)
			}
		}
	}

	func addItem(_ item: CloudItemMetadata) {
		items.append(item)
		items.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
		changeListener?()
	}
}
