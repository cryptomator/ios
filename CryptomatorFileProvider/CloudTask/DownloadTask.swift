//
//  DownloadTask.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 27.05.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation
import GRDB

struct DownloadTask: CloudTask {
	let taskRecord: DownloadTaskRecord
	let itemMetadata: ItemMetadata
	let onURLSessionTaskCreation: URLSessionTaskCreationClosure?

	enum CodingKeys: String, CodingKey {
		case taskRecord = "downloadTask"
		case itemMetadata
	}
}

typealias URLSessionTaskCreationClosure = (URLSessionTask) -> Void
