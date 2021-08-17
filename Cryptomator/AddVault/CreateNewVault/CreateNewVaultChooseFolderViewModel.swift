//
//  CreateNewVaultChooseFolderViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 18.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import Foundation

protocol CreateNewVaultChooseFolderViewModelProtocol: ChooseFolderViewModelProtocol {
	var vaultName: String { get }
	func chooseCurrentFolder() throws -> Folder
}

class CreateNewVaultChooseFolderViewModel: ChooseFolderViewModel, CreateNewVaultChooseFolderViewModelProtocol {
	let vaultName: String

	init(vaultName: String, cloudPath: CloudPath, provider: CloudProvider) {
		self.vaultName = vaultName
		super.init(canCreateFolder: true, cloudPath: cloudPath, provider: provider)
	}

	func chooseCurrentFolder() throws -> Folder {
		guard !items.contains(where: { $0.name == vaultName }) else {
			throw CreateNewVaultChooseFolderViewModelError.vaultNameCollision(name: vaultName)
		}
		let vaultPath = cloudPath.appendingPathComponent(vaultName)
		return Folder(path: vaultPath)
	}
}

enum CreateNewVaultChooseFolderViewModelError: LocalizedError {
	case vaultNameCollision(name: String)

	var errorDescription: String? {
		switch self {
		case let .vaultNameCollision(name: name):
			return String(format: LocalizedString.getValue("addVault.createNewVault.chooseFolder.error.vaultNameCollision"), name)
		}
	}
}
