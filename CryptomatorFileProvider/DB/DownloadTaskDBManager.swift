//
//  DownloadTaskDBManager.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 19.10.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation
import GRDB

protocol DownloadTaskManager {
	func createTask(for item: ItemMetadata, replaceExisting: Bool, localURL: URL, onURLSessionTaskCreation: URLSessionTaskCreationClosure?) throws -> DownloadTask
	func removeTaskRecord(_ task: DownloadTaskRecord) throws
}

class DownloadTaskDBManager: DownloadTaskManager {
	private let database: DatabaseWriter

	init(database: DatabaseWriter) throws {
		self.database = database
		_ = try database.write { db in
			try ItemEnumerationTaskRecord.deleteAll(db)
		}
	}

	func createTask(for item: ItemMetadata, replaceExisting: Bool, localURL: URL, onURLSessionTaskCreation: URLSessionTaskCreationClosure?) throws -> DownloadTask {
		try database.write { db in
			let taskRecord = DownloadTaskRecord(correspondingItem: item.id!, replaceExisting: replaceExisting, localURL: localURL)
			try taskRecord.save(db)
			return DownloadTask(taskRecord: taskRecord, itemMetadata: item, onURLSessionTaskCreation: onURLSessionTaskCreation)
		}
	}

	func removeTaskRecord(_ task: DownloadTaskRecord) throws {
		_ = try database.write { db in
			try task.delete(db)
		}
	}
}
