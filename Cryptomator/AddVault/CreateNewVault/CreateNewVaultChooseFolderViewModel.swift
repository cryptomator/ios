//
//  CreateNewVaultChooseFolderViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 18.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation
protocol CreateNewVaultChooseFolderViewModelProtocol: ChooseFolderViewModelProtocol {
	var vaultName: String { get }
	func chooseCurrentFolder() throws -> Item
}

class CreateNewVaultChooseFolderViewModel: ChooseFolderViewModel, CreateNewVaultChooseFolderViewModelProtocol {
	let vaultName: String

	init(vaultName: String, cloudPath: CloudPath, provider: CloudProvider) {
		self.vaultName = vaultName
		super.init(canCreateFolder: true, cloudPath: cloudPath, provider: provider)
	}

	func chooseCurrentFolder() throws -> Item {
		guard !items.contains(where: { $0.name == vaultName }) else {
			throw CreateNewVaultChooseFolderViewModelError.vaultNameCollision
		}
		let vaultPath = cloudPath.appendingPathComponent(vaultName)
		return Item(type: .folder, path: vaultPath)
	}
}

enum CreateNewVaultChooseFolderViewModelError: Error {
	case vaultNameCollision
}
