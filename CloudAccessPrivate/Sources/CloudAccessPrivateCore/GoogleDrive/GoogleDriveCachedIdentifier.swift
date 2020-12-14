//
//  GoogleDriveCachedIdentifier.swift
//  CloudAccessPrivate-Core
//
//  Created by Philipp Schmid on 11.05.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import Foundation
import GRDB

struct GoogleDriveCachedIdentifier: Decodable, FetchableRecord, TableRecord {
	static let databaseTableName = "googleDriveCachedIdentifiers"
	static let itemIdentifierKey = "itemIdentifier"
	static let cloudPathKey = "cloudPath"

	var itemIdentifier: String
	let cloudPath: CloudPath
}

extension GoogleDriveCachedIdentifier: PersistableRecord {
	func encode(to container: inout PersistenceContainer) {
		container[GoogleDriveCachedIdentifier.itemIdentifierKey] = itemIdentifier
		container[GoogleDriveCachedIdentifier.cloudPathKey] = cloudPath
	}
}
