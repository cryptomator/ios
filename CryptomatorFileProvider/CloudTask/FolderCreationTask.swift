//
//  FolderCreationTask.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 07.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore

struct FolderCreationTask: CloudTask {
	let itemMetadata: ItemMetadata
	let cloudPath: CloudPath

	func with(cloudPath: CloudPath) -> FolderCreationTask {
		return FolderCreationTask(itemMetadata: itemMetadata, cloudPath: cloudPath)
	}
}
