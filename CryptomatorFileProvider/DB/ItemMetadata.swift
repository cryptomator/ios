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

public class ItemMetadata: Record {
	override public class var databaseTableName: String {
		"metadata"
	}

//	static let databaseTableName = "metadata"
//	static let databaseSelection: [SQLSelectable] = [AllColumns(), Column.rowID]
	override public static var databaseSelection: [SQLSelectable] {
		[AllColumns(), Column.rowID]
	}

	var id: Int64?
	var name: String
	let type: CloudItemType
	var size: Int?
	var parentId: Int64
	var lastModifiedDate: Date?
	var statusCode: ItemStatus
	var cloudPath: CloudPath
	var isPlaceholderItem: Bool
	var isMaybeOutdated: Bool
	static let idKey = "id"
	static let nameKey = "name"
	static let typeKey = "type"
	static let sizeKey = "size"
	static let parentIdKey = "parentId"
	static let lastModifiedDateKey = "lastModifiedDate"
	static let statusCodeKey = "statusCode"
	static let cloudPathKey = "cloudPath"
	static let isPlaceholderItemKey = "isPlaceholderItem"
	static let isMaybeOutdatedKey = "isMaybeOutdated"

	required init(row: Row) {
		self.id = row[ItemMetadata.idKey]
		self.name = row[ItemMetadata.nameKey]
		self.type = row[ItemMetadata.typeKey]
		self.size = row[ItemMetadata.sizeKey]
		self.parentId = row[ItemMetadata.parentIdKey]
		self.lastModifiedDate = row[ItemMetadata.lastModifiedDateKey]
		self.statusCode = row[ItemMetadata.statusCodeKey]
		self.cloudPath = row[ItemMetadata.cloudPathKey]
		self.isPlaceholderItem = row[ItemMetadata.isPlaceholderItemKey]
		self.isMaybeOutdated = row[ItemMetadata.isMaybeOutdatedKey]
		super.init(row: row)
	}

	init(id: Int64? = nil, name: String, type: CloudItemType, size: Int?, parentId: Int64, lastModifiedDate: Date?, statusCode: ItemStatus, cloudPath: CloudPath, isPlaceholderItem: Bool, isCandidateForCacheCleanup: Bool = false) {
		self.id = id
		self.name = name
		self.type = type
		self.size = size
		self.parentId = parentId
		self.lastModifiedDate = lastModifiedDate
		self.statusCode = statusCode
		self.cloudPath = cloudPath
		self.isPlaceholderItem = isPlaceholderItem
		self.isMaybeOutdated = isCandidateForCacheCleanup
		super.init()
	}

	override public func didInsert(with rowID: Int64, for column: String?) {
		id = rowID
	}

	override public func encode(to container: inout PersistenceContainer) {
		container[ItemMetadata.idKey] = id
		container[ItemMetadata.nameKey] = name
		container[ItemMetadata.typeKey] = type
		container[ItemMetadata.sizeKey] = size
		container[ItemMetadata.parentIdKey] = parentId
		container[ItemMetadata.lastModifiedDateKey] = lastModifiedDate
		container[ItemMetadata.statusCodeKey] = statusCode
		container[ItemMetadata.cloudPathKey] = cloudPath
		container[ItemMetadata.isPlaceholderItemKey] = isPlaceholderItem
		container[ItemMetadata.isMaybeOutdatedKey] = isMaybeOutdated
	}
}

extension CloudItemType: DatabaseValueConvertible {}
extension ItemStatus: DatabaseValueConvertible {}
