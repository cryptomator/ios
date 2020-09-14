//
//  DeletionTaskManager.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 12.09.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Foundation
import GRDB

class DeletionTaskManager {
	let dbQueue: DatabaseQueue
	init(with dbQueue: DatabaseQueue) throws {
		self.dbQueue = dbQueue
		_ = try dbQueue.write { db in
			try DeletionTask.deleteAll(db)
		}
	}

	func createTask(for item: ItemMetadata) throws {
		_ = try dbQueue.write { db in
			let remoteURL = URL(fileURLWithPath: item.remotePath, isDirectory: item.type == .folder)
			try DeletionTask(correspondingItem: item.id!, remoteURL: remoteURL, parentId: item.parentId).save(db)
		}
	}

	func getTask(for id: Int64) throws -> DeletionTask {
		try dbQueue.read { db in
			guard let task = try DeletionTask.fetchOne(db, key: id) else {
				throw TaskError.taskNotFound
			}
			return task
		}
	}

	func removeTask(_ task: DeletionTask) throws {
		_ = try dbQueue.write { db in
			try task.delete(db)
		}
	}

	func getTasksForItemsWhichWere(in parentId: Int64) throws -> [DeletionTask] {
		let tasks: [DeletionTask] = try dbQueue.read { db in
			return try DeletionTask
				.filter(Column("parentId") == parentId)
				.fetchAll(db)
		}
		return tasks
	}
}
