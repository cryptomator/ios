//
//  DeletionTaskRecord.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 01.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation
import GRDB

struct DeletionTaskRecord: Decodable, FetchableRecord, TableRecord {
	static let databaseTableName = "deletionTasks"
	static let correspondingItemKey = "correspondingItem"
	static let cloudPathKey = "cloudPath"
	static let parentIdKey = "parentID"
	static let itemTypeKey = "itemType"
	let correspondingItem: Int64
	let cloudPath: CloudPath
	let parentID: Int64
	let itemType: CloudItemType
}

extension DeletionTaskRecord {
	static let itemMetadata = belongsTo(ItemMetadata.self, key: "metadata")
	var itemMetadata: QueryInterfaceRequest<ItemMetadata> {
		request(for: DeletionTaskRecord.itemMetadata)
	}
}

extension DeletionTaskRecord: PersistableRecord {
	func encode(to container: inout PersistenceContainer) {
		container[DeletionTaskRecord.correspondingItemKey] = correspondingItem
		container[DeletionTaskRecord.cloudPathKey] = cloudPath
		container[DeletionTaskRecord.parentIdKey] = parentID
		container[DeletionTaskRecord.itemTypeKey] = itemType
	}
}
