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
	var statusCode: ItemStatus
	let remotePath: String
	var isPlaceholderItem: Bool
	static let idKey = "id"
	static let nameKey = "name"
	static let typeKey = "type"
	static let sizeKey = "size"
	static let parentIdKey = "parentId"
	static let lastModifiedDateKey = "lastModifiedDate"
	static let statusCodeKey = "statusCode"
	static let remotePathKey = "remotePath"
	static let isPlaceholderItemKey = "isPlaceholderItem"

	required init(row: Row) {
		self.id = row[ItemMetadata.idKey]
		self.name = row[ItemMetadata.nameKey]
		self.type = row[ItemMetadata.typeKey]
		self.size = row[ItemMetadata.sizeKey]
		self.parentId = row[ItemMetadata.parentIdKey]
		self.lastModifiedDate = row[ItemMetadata.lastModifiedDateKey]
		self.statusCode = row[ItemMetadata.statusCodeKey]
		self.remotePath = row[ItemMetadata.remotePathKey]
		self.isPlaceholderItem = row[ItemMetadata.isPlaceholderItemKey]
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
		container[ItemMetadata.idKey] = id
		container[ItemMetadata.nameKey] = name
		container[ItemMetadata.typeKey] = type
		container[ItemMetadata.sizeKey] = size
		container[ItemMetadata.parentIdKey] = parentId
		container[ItemMetadata.lastModifiedDateKey] = lastModifiedDate
		container[ItemMetadata.statusCodeKey] = statusCode
		container[ItemMetadata.remotePathKey] = remotePath
		container[ItemMetadata.isPlaceholderItemKey] = isPlaceholderItem
	}
}

extension CloudItemType: DatabaseValueConvertible {}
extension ItemStatus: DatabaseValueConvertible {}
