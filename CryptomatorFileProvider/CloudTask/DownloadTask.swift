//
//  DownloadTask.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 27.05.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation

struct DownloadTask: CloudTask {
	let taskRecord: DownloadTaskRecord
	let itemMetadata: ItemMetadata
	let cloudPath: CloudPath
	let onURLSessionTaskCreation: URLSessionTaskCreationClosure?

	func with(cloudPath: CloudPath) -> DownloadTask {
		return DownloadTask(taskRecord: taskRecord, itemMetadata: itemMetadata, cloudPath: cloudPath, onURLSessionTaskCreation: onURLSessionTaskCreation)
	}
}

typealias URLSessionTaskCreationClosure = (URLSessionTask) -> Void
