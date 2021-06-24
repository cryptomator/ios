//
//  OpenExistingLocalVaultViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 23.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation
class OpenExistingLocalVaultViewModel: ChooseFolderViewModel {
	let rootFolderName: String
	init(rootFolderName: String, provider: LocalFileSystemProvider) {
		self.rootFolderName = rootFolderName
		super.init(canCreateFolder: false, cloudPath: CloudPath("/"), provider: provider)
	}

	override var headerTitle: String {
		return CloudPath(rootFolderName).path
	}

	override func getVaultName(for cryptomatorFilePath: CloudPath) -> String {
		return rootFolderName
	}
}
