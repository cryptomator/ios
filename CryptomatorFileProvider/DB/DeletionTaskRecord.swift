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
	let correspondingItem: Int64
	let cloudPath: CloudPath
	let parentID: Int64
	let itemType: CloudItemType

	enum Columns: String, ColumnExpression {
		case correspondingItem, cloudPath, parentID, itemType
	}
}

extension DeletionTaskRecord {
	static let itemMetadata = belongsTo(ItemMetadata.self)
	var itemMetadata: QueryInterfaceRequest<ItemMetadata> {
		request(for: DeletionTaskRecord.itemMetadata)
	}
}

extension DeletionTaskRecord: PersistableRecord {
	func encode(to container: inout PersistenceContainer) {
		container[Columns.correspondingItem] = correspondingItem
		container[Columns.cloudPath] = cloudPath
		container[Columns.parentID] = parentID
		container[Columns.itemType] = itemType
	}
}
