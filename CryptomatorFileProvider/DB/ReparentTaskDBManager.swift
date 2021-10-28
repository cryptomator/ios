//
//  ReparentTaskDBManager.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 22.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation
import GRDB

protocol ReparentTaskManager {
	func createTaskRecord(for itemMetadata: ItemMetadata, targetCloudPath: CloudPath, newParentID: Int64) throws -> ReparentTaskRecord
	func removeTaskRecord(_ task: ReparentTaskRecord) throws
	func getTaskRecordsForItemsWhichWere(in parentID: Int64) throws -> [ReparentTaskRecord]
	func getTaskRecordsForItemsWhichAreSoon(in parentID: Int64) throws -> [ReparentTaskRecord]
	func getTask(for taskRecord: ReparentTaskRecord) throws -> ReparentTask
}

class ReparentTaskDBManager: ReparentTaskManager {
	private let database: DatabaseWriter

	init(database: DatabaseWriter) throws {
		self.database = database
		_ = try database.write { db in
			try ReparentTaskRecord.deleteAll(db)
		}
	}

	func createTaskRecord(for itemMetadata: ItemMetadata, targetCloudPath: CloudPath, newParentID: Int64) throws -> ReparentTaskRecord {
		guard let id = itemMetadata.id else {
			throw DBManagerError.nonSavedItemMetadata
		}
		return try database.write { db in
			let task = ReparentTaskRecord(correspondingItem: id, sourceCloudPath: itemMetadata.cloudPath, targetCloudPath: targetCloudPath, oldParentID: itemMetadata.parentID, newParentID: newParentID)
			try task.save(db)
			return task
		}
	}

	func removeTaskRecord(_ task: ReparentTaskRecord) throws {
		_ = try database.write { db in
			try task.delete(db)
		}
	}

	func getTaskRecordsForItemsWhichWere(in parentID: Int64) throws -> [ReparentTaskRecord] {
		let tasks: [ReparentTaskRecord] = try database.read { db in
			return try ReparentTaskRecord
				.filter(ReparentTaskRecord.Columns.oldParentID == parentID)
				.fetchAll(db)
		}
		return tasks
	}

	func getTaskRecordsForItemsWhichAreSoon(in parentID: Int64) throws -> [ReparentTaskRecord] {
		let tasks: [ReparentTaskRecord] = try database.read { db in
			return try ReparentTaskRecord
				.filter(ReparentTaskRecord.Columns.newParentID == parentID)
				.fetchAll(db)
		}
		return tasks
	}

	func getTask(for taskRecord: ReparentTaskRecord) throws -> ReparentTask {
		try database.read { db in
			guard let itemMetadata = try taskRecord.itemMetadata.fetchOne(db) else {
				throw DBManagerError.missingItemMetadata
			}
			return ReparentTask(taskRecord: taskRecord, itemMetadata: itemMetadata)
		}
	}
}
