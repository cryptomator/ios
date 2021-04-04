//
//  FolderBrowserViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 09.11.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//
import CryptomatorCommonCore
import CryptomatorCloudAccessCore
import Foundation
import Promises
import UIKit
class FolderBrowserViewModel {
	private(set) var isLoading: Bool = false
	private(set) var fetchedAllItems: Bool = false
	private let folder: CloudPath
	private(set) var nextPageToken: String?
	private(set) var items = [CloudItemMetadata]()
	private let providerAccountUID: String
	weak var coordinator: AddVaultCoordinator?

	init(providerAccountUID: String, folder: CloudPath) {
		self.providerAccountUID = providerAccountUID
		self.folder = folder
	}

	func fetchItemList() -> Promise<Void> {
		guard !fetchedAllItems, !isLoading else {
			return Promise(())
		}
		let provider: CloudProvider
		do {
			provider = try CloudProviderManager.shared.getProvider(with: providerAccountUID)
		} catch {
			return Promise(error)
		}
		isLoading = true
		return provider.fetchItemList(forFolderAt: folder, withPageToken: nextPageToken).then { itemList -> Void in
			self.items.append(contentsOf: itemList.items)
			if let nextPageToken = itemList.nextPageToken {
				self.nextPageToken = nextPageToken
			} else {
				self.fetchedAllItems = true
			}
			self.isLoading = false
		}
	}

	func didSelect(row: Int) -> UIViewController {
		// TODO: safe array access
		let selectedPath = items[row].cloudPath
		if selectedPath.path.hasSuffix("masterkey.cryptomator") {
			let existingVaultInstallerViewModel = ExistingVaultInstallerViewModel(providerAccountUID: providerAccountUID, masterkeyPath: selectedPath)
			let vc = ExistingVaultInstallViewController(viewModel: existingVaultInstallerViewModel)
			vc.coordinator = coordinator
			return vc
		} else {
			let folderBrowserViewModel = FolderBrowserViewModel(providerAccountUID: providerAccountUID, folder: selectedPath)
			folderBrowserViewModel.coordinator = coordinator
			return FolderBrowserViewController(viewModel: folderBrowserViewModel)
		}
	}
}
