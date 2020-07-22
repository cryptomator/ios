//
//  ReparentTaskManager.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 22.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

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

	func createTask(for id: Int64, oldRemoteURL: URL, newRemoteURL: URL, oldParentId: Int64, newParentId: Int64) throws {
		try dbQueue.write { db in
			try ReparentTask(correspondingItem: id, oldRemoteURL: oldRemoteURL, newRemoteURL: newRemoteURL, oldParentId: oldParentId, newParentId: newParentId).save(db)
		}
	}

	func getTask(for id: Int64) throws -> ReparentTask {
		try dbQueue.read { db in
			guard let task = try ReparentTask.fetchOne(db) else {
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

//	func getTasks(for oldRemoteURLs: [URL]) throws -> [ReparentTask?] {
	// It would be better to use this function, but it does not return a Nil entry for a non-existent task and thus breaks the bijective relationship.
//		let tasks:[ReparentTask?] = try dbQueue.read{ db in
//			var keys = [[String: URL]]()
//			oldRemoteURLs.forEach { oldRemoteURL in
//				keys.append(["oldRemoteURL" : oldRemoteURL])
//			}
//			return try ReparentTask.fetchAll(db, keys: keys)
//		}
//		return tasks
//		return try dbQueue.read{ db in
//			var tasks = [ReparentTask?]()
//			for oldRemoteURL in oldRemoteURLs {
//				let task = try ReparentTask.fetchOne(db, key: ["oldRemoteURL" : oldRemoteURL])
//				tasks.append(task)
//			}
//			return tasks
//		}
//	}
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
