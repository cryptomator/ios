//
//  DeletionTask.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 12.09.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore

struct DeletionTask: CloudTask {
	let taskRecord: DeletionTaskRecord
	let itemMetadata: ItemMetadata
	let cloudPath: CloudPath

	func with(cloudPath: CloudPath) -> DeletionTask {
		return DeletionTask(taskRecord: taskRecord, itemMetadata: itemMetadata, cloudPath: cloudPath)
	}
}
