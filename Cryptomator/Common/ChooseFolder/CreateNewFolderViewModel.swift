//
//  CreateNewFolderViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 17.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation
import Promises
protocol CreateNewFolderViewModelProtocol: SingleSectionHeaderTableViewModelProtocol {
	var folderName: String? { get set }
	func createFolder() -> Promise<CloudPath>
}

class CreateNewFolderViewModel: CreateNewFolderViewModelProtocol {
	let headerTitle = NSLocalizedString("createNewFolder.header.title", comment: "")
	let headerUppercased = false

	var folderName: String?
	private let parentPath: CloudPath
	private let provider: CloudProvider

	init(parentPath: CloudPath, provider: CloudProvider) {
		self.parentPath = parentPath
		self.provider = provider
	}

	func createFolder() -> Promise<CloudPath> {
		guard let folderName = folderName, !folderName.isEmpty else {
			return Promise(CreateNewFolderViewModelError.emptyFolderName)
		}
		let folderPath = parentPath.appendingPathComponent(folderName)
		return provider.createFolder(at: folderPath).then {
			folderPath
		}
	}
}

enum CreateNewFolderViewModelError: Error {
	case emptyFolderName
}
