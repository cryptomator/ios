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
	func createTaskRecord(for id: Int64, oldCloudPath: CloudPath, newCloudPath: CloudPath, oldParentId: Int64, newParentId: Int64) throws -> ReparentTaskRecord
	func getTaskRecord(for id: Int64) throws -> ReparentTaskRecord
	func removeTaskRecord(_ task: ReparentTaskRecord) throws
	func getTaskRecordsForItemsWhichWere(in parentId: Int64) throws -> [ReparentTaskRecord]
	func getTaskRecordsForItemsWhichAreSoon(in parentId: Int64) throws -> [ReparentTaskRecord]
	func getTask(for taskRecord: ReparentTaskRecord) throws -> ReparentTask
}

class ReparentTaskDBManager: ReparentTaskManager {
	let dbPool: DatabasePool
	init(with dbPool: DatabasePool) throws {
		self.dbPool = dbPool
		_ = try dbPool.write { db in
			try ReparentTaskRecord.deleteAll(db)
		}
	}

	func createTaskRecord(for id: Int64, oldCloudPath: CloudPath, newCloudPath: CloudPath, oldParentId: Int64, newParentId: Int64) throws -> ReparentTaskRecord {
		try dbPool.write { db in
			let task = ReparentTaskRecord(correspondingItem: id, sourceCloudPath: oldCloudPath, targetCloudPath: newCloudPath, oldParentId: oldParentId, newParentId: newParentId)
			try task.save(db)
			return task
		}
	}

	func getTaskRecord(for id: Int64) throws -> ReparentTaskRecord {
		try dbPool.read { db in
			guard let task = try ReparentTaskRecord.fetchOne(db, key: id) else {
				throw TaskError.taskNotFound
			}
			return task
		}
	}

	func removeTaskRecord(_ task: ReparentTaskRecord) throws {
		_ = try dbPool.write { db in
			try task.delete(db)
		}
	}

	func getTaskRecordsForItemsWhichWere(in parentId: Int64) throws -> [ReparentTaskRecord] {
		let tasks: [ReparentTaskRecord] = try dbPool.read { db in
			return try ReparentTaskRecord
				.filter(Column("oldParentId") == parentId)
				.fetchAll(db)
		}
		return tasks
	}

	func getTaskRecordsForItemsWhichAreSoon(in parentId: Int64) throws -> [ReparentTaskRecord] {
		let tasks: [ReparentTaskRecord] = try dbPool.read { db in
			return try ReparentTaskRecord
				.filter(Column("newParentId") == parentId)
				.fetchAll(db)
		}
		return tasks
	}

	func getTask(for taskRecord: ReparentTaskRecord) throws -> ReparentTask {
		try dbPool.read { db in
			guard let itemMetadata = try taskRecord.itemMetadata.fetchOne(db) else {
				throw DeletionTaskManagerError.missingItemMetadata
			}
			return ReparentTask(taskRecord: taskRecord, itemMetadata: itemMetadata)
		}
	}
}
