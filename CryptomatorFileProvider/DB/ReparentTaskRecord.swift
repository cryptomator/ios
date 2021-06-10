//
//  ReparentTaskRecord.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 01.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation
import GRDB

struct ReparentTaskRecord: Decodable, FetchableRecord, TableRecord {
	static let databaseTableName = "reparentTasks"

	let correspondingItem: Int64
	let sourceCloudPath: CloudPath
	let targetCloudPath: CloudPath
	let oldParentID: Int64
	let newParentID: Int64

	enum Columns: String, ColumnExpression {
		case correspondingItem, sourceCloudPath, targetCloudPath, oldParentID, newParentID
	}
}

extension ReparentTaskRecord: PersistableRecord {
	func encode(to container: inout PersistenceContainer) {
		container[Columns.correspondingItem] = correspondingItem
		container[Columns.sourceCloudPath] = sourceCloudPath
		container[Columns.targetCloudPath] = targetCloudPath
		container[Columns.oldParentID] = oldParentID
		container[Columns.newParentID] = newParentID
	}
}

extension ReparentTaskRecord {
	static let itemMetadata = belongsTo(ItemMetadata.self)
	var itemMetadata: QueryInterfaceRequest<ItemMetadata> {
		request(for: ReparentTaskRecord.itemMetadata)
	}
}
