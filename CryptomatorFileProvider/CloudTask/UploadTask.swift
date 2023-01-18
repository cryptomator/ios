//
//  UploadTask.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 08.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Foundation
import GRDB

struct UploadTask: CloudTask {
	let taskRecord: UploadTaskRecord
	let itemMetadata: ItemMetadata
	let onURLSessionTaskCreation: URLSessionTaskCreationClosure?
}
