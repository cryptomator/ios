//
//  UploadTaskManager.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 06.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation
import GRDB

class UploadTaskManager {
	let dbPool: DatabasePool
	init(with dbPool: DatabasePool) {
		self.dbPool = dbPool
	}

	func createNewTask(for identifier: Int64) throws -> UploadTask {
		return try dbPool.write { db in
			let task = UploadTask(correspondingItem: identifier, lastFailedUploadDate: nil, uploadErrorCode: nil, uploadErrorDomain: nil)
			try task.save(db)
			return task
		}
	}

	func getTask(for identifier: Int64) throws -> UploadTask? {
		let uploadTask = try dbPool.read { db in
			return try UploadTask.fetchOne(db, key: identifier)
		}
		return uploadTask
	}

	func updateTask(with identifier: Int64, lastFailedUploadDate: Date, uploadErrorCode: Int, uploadErrorDomain: String) throws {
		try dbPool.write { db in
			if var task = try UploadTask.fetchOne(db, key: identifier) {
				task.lastFailedUploadDate = lastFailedUploadDate
				task.uploadErrorCode = uploadErrorCode
				task.uploadErrorDomain = uploadErrorDomain
				try task.update(db)
			} else {
				throw TaskError.taskNotFound
			}
		}
	}

	func updateTask(_ task: inout UploadTask, error: NSError) throws {
		_ = try dbPool.write { db in
			task.lastFailedUploadDate = Date()
			task.uploadErrorCode = error.code
			task.uploadErrorDomain = error.domain
			try task.update(db)
		}
	}

	func getCorrespondingTasks(ids: [Int64]) throws -> [UploadTask?] {
		let uploadTasks: [UploadTask?] = try dbPool.read { db in
			var tasks = [UploadTask?]()
			for id in ids {
				let task = try UploadTask.fetchOne(db, key: id)
				tasks.append(task)
			}
			return tasks
		}
		return uploadTasks
	}

	func updateTask(_ task: UploadTask) throws {
		_ = try dbPool.write { db in
			try task.update(db)
		}
	}

	func removeTask(for identifier: Int64) throws {
		_ = try dbPool.write { db in
			try UploadTask.deleteOne(db, key: identifier)
		}
	}
}
