//
//  DeletionTaskDBManager.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 12.09.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Foundation
import GRDB

protocol DeletionTaskManager {
	func createTaskRecord(for item: ItemMetadata) throws -> DeletionTaskRecord
	func getTaskRecord(for id: Int64) throws -> DeletionTaskRecord
	func removeTaskRecord(_ task: DeletionTaskRecord) throws
	func getTaskRecordsForItemsWhichWere(in parentID: Int64) throws -> [DeletionTaskRecord]
	func getTask(for taskRecord: DeletionTaskRecord) throws -> DeletionTask
}

class DeletionTaskDBManager: DeletionTaskManager {
	private let database: DatabaseWriter

	init(database: DatabaseWriter) throws {
		self.database = database
		_ = try database.write { db in
			try DeletionTaskRecord.deleteAll(db)
		}
	}

	func createTaskRecord(for item: ItemMetadata) throws -> DeletionTaskRecord {
		try database.write { db in
			let task = DeletionTaskRecord(correspondingItem: item.id!, cloudPath: item.cloudPath, parentID: item.parentID, itemType: item.type)
			try task.save(db)
			return task
		}
	}

	func getTaskRecord(for id: Int64) throws -> DeletionTaskRecord {
		try database.read { db in
			guard let task = try DeletionTaskRecord.fetchOne(db, key: id) else {
				throw DBManagerError.taskNotFound
			}
			return task
		}
	}

	func removeTaskRecord(_ task: DeletionTaskRecord) throws {
		_ = try database.write { db in
			try task.delete(db)
		}
	}

	func getTaskRecordsForItemsWhichWere(in parentID: Int64) throws -> [DeletionTaskRecord] {
		let tasks: [DeletionTaskRecord] = try database.read { db in
			return try DeletionTaskRecord
				.filter(DeletionTaskRecord.Columns.parentID == parentID)
				.fetchAll(db)
		}
		return tasks
	}

	func getTask(for taskRecord: DeletionTaskRecord) throws -> DeletionTask {
		try database.read { db in
			guard let itemMetadata = try taskRecord.itemMetadata.fetchOne(db) else {
				throw DBManagerError.missingItemMetadata
			}
			return DeletionTask(taskRecord: taskRecord, itemMetadata: itemMetadata)
		}
	}
}
