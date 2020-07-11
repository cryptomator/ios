//
//  UploadTaskManager.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 06.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import Foundation
import GRDB

class UploadTaskManager {
	/* let dbPool: DatabasePool

	 init(with dbPool: DatabasePool) {
	 	self.dbPool = dbPool
	 } */
	// TODO: use later a DB Pool.. dbQueue is only for demo as it supports in-memory DB
	let dbQueue: DatabaseQueue
	init(with dbQueue: DatabaseQueue) throws {
		self.dbQueue = dbQueue
		// TODO: Use Migrator to create DB
		try dbQueue.write { db in
			try db.create(table: UploadTask.databaseTableName) { table in
				table.column(UploadTask.correspondingItemKey, .integer).primaryKey().references(ItemMetadata.databaseTableName, onDelete: .cascade) // TODO: Add Reference to ItemMetadata Table in Migrator
				table.column(UploadTask.lastFailedUploadDateKey, .date)
				table.column(UploadTask.uploadErrorCodeKey, .integer)
				table.column(UploadTask.uploadErrorDomainKey, .text)

				// TODO: Discuss if constraint is necessary
				table.check(sql: "(\(UploadTask.lastFailedUploadDateKey) is NULL and \(UploadTask.uploadErrorCodeKey) is NULL and \(UploadTask.uploadErrorDomainKey) is NULL) OR (\(UploadTask.lastFailedUploadDateKey) is NOT NULL and \(UploadTask.uploadErrorCodeKey) is NOT NULL and \(UploadTask.uploadErrorDomainKey) is NOT NULL)")
			}
		}
	}

	func addNewTask(for identifier: Int64) throws {
		try dbQueue.write { db in
			try UploadTask(correspondingItem: identifier, lastFailedUploadDate: nil, uploadErrorCode: nil, uploadErrorDomain: nil).save(db)
		}
	}

	func getTask(for identifier: Int64) throws -> UploadTask? {
		let uploadTask = try dbQueue.read { db in
			return try UploadTask.fetchOne(db, key: identifier)
		}
		return uploadTask
	}

	func updateTask(with identifier: Int64, lastFailedUploadDate: Date, uploadErrorCode: Int, uploadErrorDomain: String) throws {
		try dbQueue.write { db in
			if var task = try UploadTask.fetchOne(db, key: identifier) {
				task.lastFailedUploadDate = lastFailedUploadDate
				task.uploadErrorCode = uploadErrorCode
				task.uploadErrorDomain = uploadErrorDomain
				try task.update(db)
			} else {
				throw UploadTaskError.taskNotFound
			}
		}
	}

	func updateTask(_ task: inout UploadTask?, error: NSError) throws {
		_ = try dbQueue.write { db in
			task?.lastFailedUploadDate = Date()
			task?.uploadErrorCode = error.code
			task?.uploadErrorDomain = error.domain
			try task?.update(db)
		}
	}

	func updateTask(_ task: UploadTask) throws {
		_ = try dbQueue.write { db in
			try task.update(db)
		}
	}

	func removeTask(for identifier: Int64) throws {
		_ = try dbQueue.write { db in
			try UploadTask.deleteOne(db, key: identifier)
		}
	}
}
