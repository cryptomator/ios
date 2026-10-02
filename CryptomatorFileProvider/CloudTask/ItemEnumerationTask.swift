//
//  ItemEnumerationTask.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 29.05.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore

struct ItemEnumerationTask: CloudTask {
	let taskRecord: ItemEnumerationTaskRecord
	let itemMetadata: ItemMetadata
	let cloudPath: CloudPath

	func with(cloudPath: CloudPath) -> ItemEnumerationTask {
		return ItemEnumerationTask(taskRecord: taskRecord, itemMetadata: itemMetadata, cloudPath: cloudPath)
	}
}
