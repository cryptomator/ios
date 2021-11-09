//
//  DownloadTaskRecord.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 19.10.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation
import GRDB

struct DownloadTaskRecord: Decodable, FetchableRecord, TableRecord {
	static let databaseTableName = "downloadTasks"
	let correspondingItem: Int64
	let replaceExisting: Bool
	let localURL: URL

	enum Columns: String, ColumnExpression {
		case correspondingItem, replaceExisting, localURL
	}
}

extension DownloadTaskRecord: PersistableRecord {
	func encode(to container: inout PersistenceContainer) {
		container[Columns.correspondingItem] = correspondingItem
		container[Columns.replaceExisting] = replaceExisting
		container[Columns.localURL] = localURL
	}
}

extension DownloadTaskRecord {
	static let itemMetadata = belongsTo(ItemMetadata.self)
	var itemMetadata: QueryInterfaceRequest<ItemMetadata> {
		request(for: DownloadTaskRecord.itemMetadata)
	}
}
