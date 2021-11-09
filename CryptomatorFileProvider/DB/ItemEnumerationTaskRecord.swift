//
//  ItemEnumerationTaskRecord.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 19.10.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation
import GRDB

struct ItemEnumerationTaskRecord: Decodable, FetchableRecord, TableRecord {
	static let databaseTableName = "itemEnumerationTasks"
	let correspondingItem: Int64
	let pageToken: String?

	enum Columns: String, ColumnExpression {
		case correspondingItem, pageToken
	}
}

extension ItemEnumerationTaskRecord: PersistableRecord {
	func encode(to container: inout PersistenceContainer) {
		container[Columns.correspondingItem] = correspondingItem
		container[Columns.pageToken] = pageToken
	}
}

extension ItemEnumerationTaskRecord {
	static let itemMetadata = belongsTo(ItemMetadata.self)
	var itemMetadata: QueryInterfaceRequest<ItemMetadata> {
		request(for: ItemEnumerationTaskRecord.itemMetadata)
	}
}
