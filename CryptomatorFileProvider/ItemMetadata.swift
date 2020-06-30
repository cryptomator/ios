//
//  ItemMetadata.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 24.06.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import Foundation
import GRDB

class ItemMetadata: Record {
	override class var databaseTableName: String {
		"metadata"
	}

//	static let databaseTableName = "metadata"
//	static let databaseSelection: [SQLSelectable] = [AllColumns(), Column.rowID]
	override static var databaseSelection: [SQLSelectable] {
		[AllColumns(), Column.rowID]
	}

	var id: Int64?
	let name: String
	let type: CloudItemType
	let size: Int?
	let parentId: Int64
	let lastModifiedDate: Date?
	let statusCode: ItemStatus
	let remotePath: String
	let isPlaceholderItem: Bool
	required init(row: Row) {
		self.id = row[Column.rowID]
		self.name = row["name"]
		self.type = row["type"]
		self.size = row["size"]
		self.parentId = row["parentId"]
		self.lastModifiedDate = row["lastModifiedDate"]
		self.statusCode = row["statusCode"]
		self.remotePath = row["remotePath"]
		self.isPlaceholderItem = row["isPlaceholderItem"]
		super.init(row: row)
	}

	init(id: Int64? = nil, name: String, type: CloudItemType, size: Int?, parentId: Int64, lastModifiedDate: Date?, statusCode: ItemStatus, remotePath: String, isPlaceholderItem: Bool) {
		self.id = id
		self.name = name
		self.type = type
		self.size = size
		self.parentId = parentId
		self.lastModifiedDate = lastModifiedDate
		self.statusCode = statusCode
		self.remotePath = remotePath
		self.isPlaceholderItem = isPlaceholderItem
		super.init()
	}

	override func didInsert(with rowID: Int64, for column: String?) {
		id = rowID
	}

	override func encode(to container: inout PersistenceContainer) {
		container[Column.rowID] = id
		container["name"] = name
		container["type"] = type
		container["size"] = size
		container["parentId"] = parentId
		container["lastModifiedDate"] = lastModifiedDate
		container["statusCode"] = statusCode
		container["remotePath"] = remotePath
		container["isPlaceholderItem"] = isPlaceholderItem
	}
}

extension CloudItemType: DatabaseValueConvertible {}
extension ItemStatus: DatabaseValueConvertible {}
