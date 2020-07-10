//
//  UploadTask.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 08.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Foundation
import GRDB

struct UploadTask: Decodable, FetchableRecord, TableRecord {
	static let databaseTableName = "uploadTasks"
	static let correspondingItemKey = "correspondingItem"
	static let lastFailedUploadDateKey = "lastFailedUploadDate"
	static let uploadErrorCodeKey = "uploadErrorCode"
	static let uploadErrorDomainKey = "uploadErrorDomain"
	let correspondingItem: Int64
	var lastFailedUploadDate: Date?
	var uploadErrorCode: Int?
	var uploadErrorDomain: String?
}

extension UploadTask: PersistableRecord {
	func encode(to container: inout PersistenceContainer) {
		container[UploadTask.correspondingItemKey] = correspondingItem
		container[UploadTask.lastFailedUploadDateKey] = lastFailedUploadDate
		container[UploadTask.uploadErrorCodeKey] = uploadErrorCode
		container[UploadTask.uploadErrorDomainKey] = uploadErrorDomain
	}
}
