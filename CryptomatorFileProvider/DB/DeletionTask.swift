//
//  DeletionTask.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 12.09.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Foundation
import GRDB
struct DeletionTask: Decodable, FetchableRecord, TableRecord {
	static let databaseTableName = "deletionTasks"
	static let correspondingItemKey = "correspondingItem"
	static let remoteURLKey = "remoteURL"
	static let parentIdKey = "parentId"
	let correspondingItem: Int64
	let remoteURL: URL
	let parentId: Int64
}

extension DeletionTask: PersistableRecord {
	func encode(to container: inout PersistenceContainer) {
		container[DeletionTask.correspondingItemKey] = correspondingItem
		container[DeletionTask.remoteURLKey] = remoteURL
		container[DeletionTask.parentIdKey] = parentId
	}
}
