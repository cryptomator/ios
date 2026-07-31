//
//  ItemEnumerationTaskDBManager.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 19.10.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation
import GRDB

protocol ItemEnumerationTaskManager {
	func createTask(for item: ItemMetadata, pageToken: String?) throws -> ItemEnumerationTask
	func removeTaskRecord(_ task: ItemEnumerationTaskRecord) throws
}

class ItemEnumerationTaskDBManager: ItemEnumerationTaskManager {
	private let database: DatabaseWriter
	private let itemMetadataManager: ItemMetadataManager

	init(database: DatabaseWriter, itemMetadataManager: ItemMetadataManager) throws {
		self.database = database
		self.itemMetadataManager = itemMetadataManager
		_ = try database.write { db in
			try ItemEnumerationTaskRecord.deleteAll(db)
		}
	}

	func createTask(for item: ItemMetadata, pageToken: String?) throws -> ItemEnumerationTask {
		guard let id = item.id else {
			throw DBManagerError.nonSavedItemMetadata
		}
		let cloudPath = try itemMetadataManager.getCloudPath(for: id)
		return try database.write { db in
			let taskRecord = ItemEnumerationTaskRecord(correspondingItem: id, pageToken: pageToken)
			try taskRecord.save(db)
			return ItemEnumerationTask(taskRecord: taskRecord, itemMetadata: item, cloudPath: cloudPath)
		}
	}

	func removeTaskRecord(_ task: ItemEnumerationTaskRecord) throws {
		_ = try database.write { db in
			try task.delete(db)
		}
	}
}
