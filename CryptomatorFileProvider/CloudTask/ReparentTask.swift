//
//  ReparentTask.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 22.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore

struct ReparentTask: CloudTask {
	let taskRecord: ReparentTaskRecord
	let itemMetadata: ItemMetadata
	let cloudPath: CloudPath

	func with(cloudPath: CloudPath, taskRecord: ReparentTaskRecord) -> ReparentTask {
		return ReparentTask(taskRecord: taskRecord, itemMetadata: itemMetadata, cloudPath: cloudPath)
	}
}
