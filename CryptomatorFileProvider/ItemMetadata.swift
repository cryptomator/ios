//
//  ItemMetadata.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 24.06.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Foundation
import GRDB
import CryptomatorCloudAccess

struct ItemMetadata: Decodable, FetchableRecord, TableRecord {
	static let databaseTableName = "metadata"

	let name: String
	let type: CloudItemType
	let size: Int?
	let remoteParentPath: String
	let lastModifiedDate: Date?
	let statusCode: ItemStatus
	let remotePath: String
	let isPlaceholderItem: Bool
}

extension ItemMetadata: PersistableRecord {
	func encode(to container: inout PersistenceContainer) {
		container["name"] = name
		container["type"] = type
		container["size"] = size
		container["remoteParentPath"] = remoteParentPath
		container["lastModifiedDate"] = lastModifiedDate
		container["statusCode"] = statusCode
		container["remotePath"] = remotePath
		container["isPlaceholderItem"] = isPlaceholderItem
	}
}

extension CloudItemType: DatabaseValueConvertible {}
extension ItemStatus: DatabaseValueConvertible {}
