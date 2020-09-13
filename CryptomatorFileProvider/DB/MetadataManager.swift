//
//  MetadataManager.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 24.06.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import FileProvider
import Foundation
import GRDB
class MetadataManager {
	private let dbQueue: DatabaseQueue
	static let rootContainerId: Int64 = 1
	init(with dbQueue: DatabaseQueue) {
		self.dbQueue = dbQueue
	}

	func cacheMetadata(_ metadata: ItemMetadata) throws {
		if let cachedMetadata = try getCachedMetadata(for: metadata.remotePath) {
			metadata.id = cachedMetadata.id
			try updateMetadata(metadata)
		} else {
			try dbQueue.write { db in
				try metadata.save(db)
			}
		}
	}

	func updateMetadata(_ metadata: ItemMetadata) throws {
		try dbQueue.write { db in
			try metadata.update(db)
		}
	}

	// TODO: Optimize Code and/or DB Scheme
	func cacheMetadatas(_ metadatas: [ItemMetadata]) throws {
		try dbQueue.inTransaction { db in
			for metadata in metadatas {
				if let cachedMetadata = try ItemMetadata.fetchOne(db, key: ["remotePath": metadata.remotePath]) {
					metadata.id = cachedMetadata.id
					try metadata.update(db)
				} else {
					try metadata.insert(db)
				}
			}
			return .commit
		}
	}

	func getCachedMetadata(for remotePath: String) throws -> ItemMetadata? {
		let itemMetadata: ItemMetadata? = try dbQueue.read { db in
			return try ItemMetadata.fetchOne(db, key: ["remotePath": remotePath])
		}
		return itemMetadata
	}

	func getCachedMetadata(for identifier: Int64) throws -> ItemMetadata? {
		let itemMetadata: ItemMetadata? = try dbQueue.read { db in
			return try ItemMetadata.fetchOne(db, key: identifier)
		}
		return itemMetadata
	}

	func getPlaceholderMetadata(for parentId: Int64) throws -> [ItemMetadata] {
		let itemMetadata: [ItemMetadata] = try dbQueue.read { db in
			return try ItemMetadata
				.filter(Column("parentId") == parentId && Column("isPlaceholderItem") && Column("id") != MetadataManager.rootContainerId)
				.fetchAll(db)
		}
		return itemMetadata
	}

	func getCachedMetadata(forParentId parentId: Int64) throws -> [ItemMetadata] {
		let itemMetadata: [ItemMetadata] = try dbQueue.read { db in
			return try ItemMetadata
				.filter(Column("parentId") == parentId && Column("id") != MetadataManager.rootContainerId)
				.fetchAll(db)
		}
		return itemMetadata
	}

	// TODO: find a more meaningful name
	func flagAllItemsAsMaybeOutdated(insideParentId parentId: Int64) throws {
		_ = try dbQueue.write { db in
			try ItemMetadata
				.filter(Column("parentId") == parentId && !Column("isPlaceholderItem"))
				.fetchAll(db)
				.forEach {
					$0.isMaybeOutdated = true
					try $0.save(db)
				}
		}
	}

	func getMaybeOutdatedItems(insideParentId parentId: Int64) throws -> [ItemMetadata] {
		try dbQueue.read { db in
			return try ItemMetadata
				.filter(Column(ItemMetadata.parentIdKey) == parentId && Column(ItemMetadata.isMaybeOutdatedKey))
				.fetchAll(db)
		}
	}

	func removeItemMetadata(with identifier: Int64) throws {
		_ = try dbQueue.write { db in
			try ItemMetadata.deleteOne(db, key: identifier)
		}
	}

	func removeItemMetadata(_ identifiers: [Int64]) throws {
		_ = try dbQueue.write { db in
			try ItemMetadata.deleteAll(db, keys: identifiers)
		}
	}

	func getCachedMetadata(forIds ids: [Int64]) throws -> [ItemMetadata] {
		try dbQueue.read { db in
			return try ItemMetadata.fetchAll(db, keys: ids)
		}
	}

	func synchronize(metadata: [ItemMetadata], with tasks: [UploadTask?]) throws {
		precondition(metadata.count == tasks.count)
		try dbQueue.inTransaction { db in
			for (index, task) in tasks.enumerated() {
				if task?.error != nil {
					let correspondingMetadata = metadata[index]
					assert(correspondingMetadata.id == task?.correspondingItem)
					correspondingMetadata.statusCode = .uploadError
					try correspondingMetadata.save(db)
				}
			}
			return .commit
		}
	}

	/**
	 Returns the items that have the item as parent because of its RemotePath. This also includes all subfolders including their items.
	 */
	func getAllCachedMetadata(inside parent: ItemMetadata) throws -> [ItemMetadata] {
		precondition(parent.type == .folder)
		// TODO: Small Hack until RemotePath is merged --> change later
		let parentRemotePath: String
		if parent.remotePath.last != "/" {
			parentRemotePath = parent.remotePath + "/"
		} else {
			parentRemotePath = parent.remotePath
		}
		return try dbQueue.read { db in
			let request = ItemMetadata.filter(Column(ItemMetadata.remotePathKey).like("\(parentRemotePath)_%"))
			return try request.fetchAll(db)
		}
	}
}
