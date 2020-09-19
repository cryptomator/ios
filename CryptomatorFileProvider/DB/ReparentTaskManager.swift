//
//  ReparentTaskManager.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 22.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import Foundation
import GRDB
class ReparentTaskManager {
	let dbQueue: DatabaseQueue
	init(with dbQueue: DatabaseQueue) throws {
		self.dbQueue = dbQueue
		_ = try dbQueue.write { db in
			try ReparentTask.deleteAll(db)
		}
	}

	func createTask(for id: Int64, oldCloudPath: CloudPath, newCloudPath: CloudPath, oldParentId: Int64, newParentId: Int64) throws {
		try dbQueue.write { db in
			try ReparentTask(correspondingItem: id, sourceCloudPath: oldCloudPath, targetCloudPath: newCloudPath, oldParentId: oldParentId, newParentId: newParentId).save(db)
		}
	}

	func getTask(for id: Int64) throws -> ReparentTask {
		try dbQueue.read { db in
			guard let task = try ReparentTask.fetchOne(db, key: id) else {
				throw TaskError.taskNotFound
			}
			return task
		}
	}

	func removeTask(_ task: ReparentTask) throws {
		_ = try dbQueue.write { db in
			try task.delete(db)
		}
	}

	func getTasksForItemsWhichWere(in parentId: Int64) throws -> [ReparentTask] {
		let tasks: [ReparentTask] = try dbQueue.read { db in
			return try ReparentTask
				.filter(Column("oldParentId") == parentId)
				.fetchAll(db)
		}
		return tasks
	}

	func getTasksForItemsWhichAreSoon(in parentId: Int64) throws -> [ReparentTask] {
		let tasks: [ReparentTask] = try dbQueue.read { db in
			return try ReparentTask
				.filter(Column("newParentId") == parentId)
				.fetchAll(db)
		}
		return tasks
	}
}
