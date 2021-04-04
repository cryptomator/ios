//
//  ReparentTaskManager.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 22.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation
import GRDB
class ReparentTaskManager {
	let dbPool: DatabasePool
	init(with dbPool: DatabasePool) throws {
		self.dbPool = dbPool
		_ = try dbPool.write { db in
			try ReparentTask.deleteAll(db)
		}
	}

	func createTask(for id: Int64, oldCloudPath: CloudPath, newCloudPath: CloudPath, oldParentId: Int64, newParentId: Int64) throws {
		try dbPool.write { db in
			try ReparentTask(correspondingItem: id, sourceCloudPath: oldCloudPath, targetCloudPath: newCloudPath, oldParentId: oldParentId, newParentId: newParentId).save(db)
		}
	}

	func getTask(for id: Int64) throws -> ReparentTask {
		try dbPool.read { db in
			guard let task = try ReparentTask.fetchOne(db, key: id) else {
				throw TaskError.taskNotFound
			}
			return task
		}
	}

	func removeTask(_ task: ReparentTask) throws {
		_ = try dbPool.write { db in
			try task.delete(db)
		}
	}

	func getTasksForItemsWhichWere(in parentId: Int64) throws -> [ReparentTask] {
		let tasks: [ReparentTask] = try dbPool.read { db in
			return try ReparentTask
				.filter(Column("oldParentId") == parentId)
				.fetchAll(db)
		}
		return tasks
	}

	func getTasksForItemsWhichAreSoon(in parentId: Int64) throws -> [ReparentTask] {
		let tasks: [ReparentTask] = try dbPool.read { db in
			return try ReparentTask
				.filter(Column("newParentId") == parentId)
				.fetchAll(db)
		}
		return tasks
	}
}
