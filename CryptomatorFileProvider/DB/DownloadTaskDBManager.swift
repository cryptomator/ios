//
//  DownloadTaskDBManager.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 19.10.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation
import GRDB

protocol DownloadTaskManager {
	func createTask(for item: ItemMetadata, replaceExisting: Bool, localURL: URL, onURLSessionTaskCreation: URLSessionTaskCreationClosure?) throws -> DownloadTask
	func removeTaskRecord(_ task: DownloadTaskRecord) throws
}

class DownloadTaskDBManager: DownloadTaskManager {
	private let database: DatabaseWriter
	private let itemMetadataManager: ItemMetadataManager

	init(database: DatabaseWriter, itemMetadataManager: ItemMetadataManager) throws {
		self.database = database
		self.itemMetadataManager = itemMetadataManager
		_ = try database.write { db in
			try DownloadTaskRecord.deleteAll(db)
		}
	}

	func createTask(for item: ItemMetadata, replaceExisting: Bool, localURL: URL, onURLSessionTaskCreation: URLSessionTaskCreationClosure?) throws -> DownloadTask {
		guard let id = item.id else {
			throw DBManagerError.nonSavedItemMetadata
		}
		let cloudPath = try itemMetadataManager.getCloudPath(for: id)
		return try database.write { db in
			let taskRecord = DownloadTaskRecord(correspondingItem: id, replaceExisting: replaceExisting, localURL: localURL)
			try taskRecord.save(db)
			return DownloadTask(taskRecord: taskRecord, itemMetadata: item, cloudPath: cloudPath, onURLSessionTaskCreation: onURLSessionTaskCreation)
		}
	}

	func removeTaskRecord(_ task: DownloadTaskRecord) throws {
		_ = try database.write { db in
			try task.delete(db)
		}
	}
}
