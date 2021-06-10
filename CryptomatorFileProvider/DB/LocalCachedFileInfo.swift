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
	static let lastModifiedDateKey = "lastModifiedDate"
	static let correspondingItemKey = "correspondingItem"
	static let localLastModifiedDateKey = "localLastModifiedDate"
	static let localURLKey = "localURL"
	let lastModifiedDate: Date?
	let correspondingItem: Int64
	let localLastModifiedDate: Date
	let localURL: URL
}

extension LocalCachedFileInfo: PersistableRecord {
	func encode(to container: inout PersistenceContainer) {
		container[LocalCachedFileInfo.lastModifiedDateKey] = lastModifiedDate
		container[LocalCachedFileInfo.correspondingItemKey] = correspondingItem
		container[LocalCachedFileInfo.localLastModifiedDateKey] = localLastModifiedDate
		container[LocalCachedFileInfo.localURLKey] = localURL
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
