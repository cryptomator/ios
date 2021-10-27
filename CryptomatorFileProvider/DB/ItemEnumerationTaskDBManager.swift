//
//  ItemEnumerationTaskDBManager.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 19.10.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation
import GRDB

protocol ItemEnumerationTaskManager {
	func createTask(for item: ItemMetadata, pageToken: String?) throws -> ItemEnumerationTask
	func removeTaskRecord(_ task: ItemEnumerationTaskRecord) throws
}

class ItemEnumerationTaskDBManager: ItemEnumerationTaskManager {
	private let database: DatabaseWriter

	init(database: DatabaseWriter) throws {
		self.database = database
		_ = try database.write { db in
			try ItemEnumerationTaskRecord.deleteAll(db)
		}
	}

	func createTask(for item: ItemMetadata, pageToken: String?) throws -> ItemEnumerationTask {
		try database.write { db in
			let taskRecord = ItemEnumerationTaskRecord(correspondingItem: item.id!, pageToken: pageToken)
			try taskRecord.save(db)
			return ItemEnumerationTask(taskRecord: taskRecord, itemMetadata: item)
		}
	}

	func removeTaskRecord(_ task: ItemEnumerationTaskRecord) throws {
		_ = try database.write { db in
			try task.delete(db)
		}
	}
}
