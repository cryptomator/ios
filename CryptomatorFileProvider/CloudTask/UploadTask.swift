//
//  UploadTask.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 08.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation

struct UploadTask: CloudTask {
	let taskRecord: UploadTaskRecord
	let itemMetadata: ItemMetadata
	let cloudPath: CloudPath
	let onURLSessionTaskCreation: URLSessionTaskCreationClosure?

	func with(cloudPath: CloudPath) -> UploadTask {
		return UploadTask(taskRecord: taskRecord, itemMetadata: itemMetadata, cloudPath: cloudPath, onURLSessionTaskCreation: onURLSessionTaskCreation)
	}
}
