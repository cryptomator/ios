//
//  CreateNewLocalVaultViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 24.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation
class CreateNewLocalVaultViewModel: CreateNewVaultChooseFolderViewModel {
	let rootFolderName: String

	init(rootFolderName: String, vaultName: String, provider: LocalFileSystemProvider) {
		self.rootFolderName = rootFolderName
		super.init(vaultName: vaultName, cloudPath: CloudPath("/"), provider: provider)
	}

	override var headerTitle: String {
		return vaultName
	}

	override func getVaultName(for cryptomatorFilePath: CloudPath) -> String {
		return vaultName
	}
}
