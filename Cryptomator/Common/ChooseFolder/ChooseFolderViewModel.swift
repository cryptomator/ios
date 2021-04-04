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
	func startListenForChanges(onError: @escaping (Error) -> Void,
	                           onChange: @escaping () -> Void,
	                           onMasterkeyDetection: @escaping (CloudPath) -> Void)
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
	private var masterkeyListener: ((CloudPath) -> Void)?

	init(canCreateFolder: Bool, cloudPath: CloudPath, provider: CloudProvider) {
		self.canCreateFolder = canCreateFolder
		self.cloudPath = cloudPath
		self.provider = provider
	}

	func startListenForChanges(onError: @escaping (Error) -> Void, onChange: @escaping () -> Void, onMasterkeyDetection: @escaping (CloudPath) -> Void) {
		errorListener = onError
		changeListener = onChange
		masterkeyListener = onMasterkeyDetection
		refreshItems()
	}

	func refreshItems() {
		provider.fetchItemListExhaustively(forFolderAt: cloudPath).then { itemList in
			if let masterkeyItem = itemList.items.first(where: { $0.name == "masterkey.cryptomator" && $0.itemType == .file }), itemList.items.contains(where: { $0.name == "d" && $0.itemType == .folder }) {
				self.foundMasterkey = true
				self.masterkeyListener?(masterkeyItem.cloudPath)
			} else {
				self.items = itemList.items
				self.changeListener?()
			}
		}.catch { error in
			self.errorListener?(error)
		}
	}
}
