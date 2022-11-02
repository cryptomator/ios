//
//  CachedFileDBManager.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 01.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import FileProvider
import Foundation
import GRDB

protocol CachedFileManager {
	func getLocalCachedFileInfo(for id: Int64) throws -> LocalCachedFileInfo?
	func cacheLocalFileInfo(for id: Int64, localURL: URL, lastModifiedDate: Date?) throws
	func removeCachedFile(for id: Int64) throws
	func clearCache() throws
	func getLocalCacheSizeInBytes() throws -> Int
}

extension CachedFileManager {
	func getLocalCachedFileInfo(for itemMetadata: ItemMetadata) throws -> LocalCachedFileInfo? {
		guard let id = itemMetadata.id else {
			throw DBManagerError.nonSavedItemMetadata
		}
		return try getLocalCachedFileInfo(for: id)
	}

	func removeCachedFile(for itemIdentifier: NSFileProviderItemIdentifier) throws {
		guard let itemID = itemIdentifier.databaseValue else {
			return
		}
		try removeCachedFile(for: itemID)
	}
}

enum CachedFileManagerError: Error {
	case fileHasUnsyncedEdits
}

class CachedFileManagerHelper {
	let fileCoordinator: NSFileCoordinator

	init(fileCoordinator: NSFileCoordinator) {
		self.fileCoordinator = fileCoordinator
	}

	/**
	 Removes the file or directory at the specified URL.

	 This sets the `.immutable` attribute of the file or directory at the specified URL to `false` prior to deletion.
	 */
	func removeItem(at url: URL) throws {
		var fileManagerError: NSError?
		var fileCoordinatorError: NSError?
		fileCoordinator.coordinate(writingItemAt: url, options: .forDeleting, error: &fileCoordinatorError) { url in
			do {
				try FileManager.default.setAttributes([.immutable: false], ofItemAtPath: url.path)
				try FileManager.default.removeItem(at: url)
			} catch let error as NSError {
				fileManagerError = error as NSError
			}
		}
		if let error = fileManagerError ?? fileCoordinatorError {
			throw error
		}
	}
}

class CachedFileDBManager: CachedFileManager {
	private let database: DatabaseWriter
	private let fileManagerHelper: CachedFileManagerHelper

	init(database: DatabaseWriter, fileManagerHelper: CachedFileManagerHelper) {
		self.database = database
		self.fileManagerHelper = fileManagerHelper
	}

	func getLocalCachedFileInfo(for id: Int64) throws -> LocalCachedFileInfo? {
		let fetchedEntry = try database.read { db in
			return try LocalCachedFileInfo.fetchOne(db, key: id)
		}
		return fetchedEntry
	}

	func cacheLocalFileInfo(for id: Int64, localURL: URL, lastModifiedDate: Date?) throws {
		try database.write { db in
			try LocalCachedFileInfo(lastModifiedDate: lastModifiedDate, correspondingItem: id, localLastModifiedDate: Date(), localURL: localURL).save(db)
		}
	}

	func removeCachedFile(for id: Int64) throws {
		return try database.write { db in
			guard try UploadTaskRecord.fetchOne(db, key: id) == nil else {
				throw CachedFileManagerError.fileHasUnsyncedEdits
			}
			guard let entry = try LocalCachedFileInfo.fetchOne(db, key: id) else {
				return
			}
			try entry.delete(db)
			do {
				try fileManagerHelper.removeItem(at: entry.localURL)
			} catch CocoaError.fileNoSuchFile {
				// no-op the local cached file is already removed and therefore it is okay to remove the entry from the DB
			}
		}
	}

	func clearCache() throws {
		try database.write { db in
			let entries = try LocalCachedFileInfo.fetchAll(db, sql: """
				  SELECT \(LocalCachedFileInfo.databaseTableName).*
				  FROM \(LocalCachedFileInfo.databaseTableName)
				  LEFT JOIN \(UploadTaskRecord.databaseTableName)
				  ON \(UploadTaskRecord.databaseTableName).correspondingItem = \(LocalCachedFileInfo.databaseTableName).correspondingItem
				  WHERE \(UploadTaskRecord.databaseTableName).correspondingItem IS NULL
			""")
			for entry in entries {
				try? db.inSavepoint({
					try entry.delete(db)
					do {
						try fileManagerHelper.removeItem(at: entry.localURL)
					} catch CocoaError.fileNoSuchFile {
						// the local cached file is already removed and therefore it is okay to remove the entry from the DB
						return .commit
					}
					return .commit
				})
			}
		}
	}

	func getLocalCacheSizeInBytes() throws -> Int {
		try database.read({ db in
			let entries = try LocalCachedFileInfo.fetchAll(db, sql: """
				  SELECT \(LocalCachedFileInfo.databaseTableName).*
				  FROM \(LocalCachedFileInfo.databaseTableName)
				  LEFT JOIN \(UploadTaskRecord.databaseTableName)
				  ON \(UploadTaskRecord.databaseTableName).correspondingItem = \(LocalCachedFileInfo.databaseTableName).correspondingItem
				  WHERE \(UploadTaskRecord.databaseTableName).correspondingItem IS NULL
			""")
			return try entries.reduce(0) {
				let attributes = try $1.localURL.resourceValues(forKeys: [.fileSizeKey])
				let filesize = attributes.fileSize ?? 0
				return filesize + $0
			}
		})
	}
}
