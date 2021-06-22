//
//  LocalCachedFileInfo.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 10.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation
import GRDB

struct LocalCachedFileInfo: Decodable, FetchableRecord, TableRecord {
	static let databaseTableName = "cachedFiles"

	let lastModifiedDate: Date?
	let correspondingItem: Int64
	let localLastModifiedDate: Date
	let localURL: URL

	enum Columns: String, ColumnExpression {
		case lastModifiedDate, correspondingItem, localLastModifiedDate, localURL
	}
}

extension LocalCachedFileInfo: PersistableRecord {
	func encode(to container: inout PersistenceContainer) {
		container[Columns.lastModifiedDate] = lastModifiedDate
		container[Columns.correspondingItem] = correspondingItem
		container[Columns.localLastModifiedDate] = localLastModifiedDate
		container[Columns.localURL] = localURL
	}
}

extension LocalCachedFileInfo {
	func isCurrentVersion(lastModifiedDateInCloud: Date?) -> Bool {
		guard let lastModifiedDateInCloud = lastModifiedDateInCloud, let lastModifiedDateLocal = lastModifiedDate else {
			return false
		}
		return Calendar(identifier: .gregorian).isDate(lastModifiedDateLocal, equalTo: lastModifiedDateInCloud, toGranularity: .second)
	}
}
