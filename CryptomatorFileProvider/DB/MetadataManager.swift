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
	private let dbPool: DatabasePool
	static let rootContainerId: Int64 = 1
	init(with dbPool: DatabasePool) {
		self.dbPool = dbPool
	}

	func cacheMetadata(_ metadata: ItemMetadata) throws {
		if let cachedMetadata = try getCachedMetadata(for: metadata.cloudPath) {
			metadata.id = cachedMetadata.id
			try updateMetadata(metadata)
		} else {
			try dbPool.write { db in
				try metadata.save(db)
			}
		}
	}

	func updateMetadata(_ metadata: ItemMetadata) throws {
		try dbPool.write { db in
			try metadata.update(db)
		}
	}

	// TODO: Optimize Code and/or DB Scheme
	func cacheMetadatas(_ metadatas: [ItemMetadata]) throws {
		try dbPool.writeInTransaction { db in
			for metadata in metadatas {
				if let cachedMetadata = try ItemMetadata.fetchOne(db, key: ["cloudPath": metadata.cloudPath]) {
					metadata.id = cachedMetadata.id
					metadata.statusCode = cachedMetadata.statusCode
					try metadata.update(db)
				} else {
					try metadata.insert(db)
				}
			}
			return .commit
		}
	}

	func getCachedMetadata(for cloudPath: CloudPath) throws -> ItemMetadata? {
		let itemMetadata: ItemMetadata? = try dbPool.read { db in
			return try ItemMetadata.fetchOne(db, key: ["cloudPath": cloudPath])
		}
		return itemMetadata
	}

	func getCachedMetadata(for identifier: Int64) throws -> ItemMetadata? {
		let itemMetadata: ItemMetadata? = try dbPool.read { db in
			return try ItemMetadata.fetchOne(db, key: identifier)
		}
		return itemMetadata
	}

	func getPlaceholderMetadata(for parentId: Int64) throws -> [ItemMetadata] {
		let itemMetadata: [ItemMetadata] = try dbPool.read { db in
			return try ItemMetadata
				.filter(Column("parentId") == parentId && Column("isPlaceholderItem") && Column("id") != MetadataManager.rootContainerId)
				.fetchAll(db)
		}
		return itemMetadata
	}

	func getCachedMetadata(forParentId parentId: Int64) throws -> [ItemMetadata] {
		let itemMetadata: [ItemMetadata] = try dbPool.read { db in
			return try ItemMetadata
				.filter(Column("parentId") == parentId && Column("id") != MetadataManager.rootContainerId)
				.fetchAll(db)
		}
		return itemMetadata
	}

	// TODO: find a more meaningful name
	func flagAllItemsAsMaybeOutdated(insideParentId parentId: Int64) throws {
		_ = try dbPool.write { db in
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
		try dbPool.read { db in
			return try ItemMetadata
				.filter(Column(ItemMetadata.parentIdKey) == parentId && Column(ItemMetadata.isMaybeOutdatedKey))
				.fetchAll(db)
		}
	}

	func removeItemMetadata(with identifier: Int64) throws {
		_ = try dbPool.write { db in
			try ItemMetadata.deleteOne(db, key: identifier)
		}
	}

	func removeItemMetadata(_ identifiers: [Int64]) throws {
		_ = try dbPool.write { db in
			try ItemMetadata.deleteAll(db, keys: identifiers)
		}
	}

	func getCachedMetadata(forIds ids: [Int64]) throws -> [ItemMetadata] {
		try dbPool.read { db in
			return try ItemMetadata.fetchAll(db, keys: ids)
		}
	}

	/**
	 Returns the items that have the item as parent because of its RemotePath. This also includes all subfolders including their items.
	 */
	func getAllCachedMetadata(inside parent: ItemMetadata) throws -> [ItemMetadata] {
		precondition(parent.type == .folder)
		return try dbPool.read { db in
			let request: QueryInterfaceRequest<ItemMetadata>
			if parent.id == MetadataManager.rootContainerId {
				request = ItemMetadata.filter(Column(ItemMetadata.idKey) != MetadataManager.rootContainerId)
			} else {
				request = ItemMetadata.filter(Column(ItemMetadata.cloudPathKey).like("\(parent.cloudPath.path + "/")_%"))
			}
			return try request.fetchAll(db)
		}
	}
}
