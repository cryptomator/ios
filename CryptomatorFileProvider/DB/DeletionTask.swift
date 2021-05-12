//
//  DeletionTask.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 12.09.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation
import GRDB

struct DeletionTask: Decodable, FetchableRecord, TableRecord {
	static let databaseTableName = "deletionTasks"
	static let correspondingItemKey = "correspondingItem"
	static let cloudPathKey = "cloudPath"
	static let parentIdKey = "parentId"
	static let itemTypeKey = "itemType"
	let correspondingItem: Int64
	let cloudPath: CloudPath
	let parentId: Int64
	let itemType: CloudItemType
}

extension DeletionTask: PersistableRecord {
	func encode(to container: inout PersistenceContainer) {
		container[DeletionTask.correspondingItemKey] = correspondingItem
		container[DeletionTask.cloudPathKey] = cloudPath
		container[DeletionTask.parentIdKey] = parentId
		container[DeletionTask.itemTypeKey] = itemType
	}
}
