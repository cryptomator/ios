//
//  WorkingSetObserver.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 21.01.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import CryptomatorCloudAccessCore
import Dependencies
import FileProvider
import Foundation
import GRDB

protocol WorkingSetObserving {
	func startObservation()
}

/// @unchecked Sendable: `observer` is assigned once in `startObservation`. `currentWorkingSetItems` is only touched on the main queue.
class WorkingSetObserver: WorkingSetObserving, @unchecked Sendable {
	private var observer: DatabaseCancellable?
	private let database: DatabaseReader
	private let uploadTaskManager: UploadTaskManager
	private let cachedFileManager: CachedFileManager
	private let notificator: FileProviderNotificatorType
	private var currentWorkingSetItems = Set<FileProviderItem>()
	private let domainIdentifier: NSFileProviderDomainIdentifier
	@Dependency(\.permissionProvider) private var permissionProvider

	init(domainIdentifier: NSFileProviderDomainIdentifier,
	     database: DatabaseReader,
	     notificator: FileProviderNotificatorType,
	     uploadTaskManager: UploadTaskManager,
	     cachedFileManager: CachedFileManager) {
		self.domainIdentifier = domainIdentifier
		self.database = database
		self.notificator = notificator
		self.uploadTaskManager = uploadTaskManager
		self.cachedFileManager = cachedFileManager
	}

	func startObservation() {
		let observation = ValueObservation.tracking { db in
			try ItemMetadata.filterWorkingSet().fetchAll(db).map(WorkingSetItemSnapshot.init)
		}.removeDuplicates()
		observer = observation.start(in: database,
		                             scheduling: .async(onQueue: .main),
		                             onError: { error in
		                             	DDLogError("Working set startObservation error: \(error)")
		                             },
		                             onChange: { [weak self] (snapshots: [WorkingSetItemSnapshot]) in
		                             	let items: [FileProviderItem]
		                             	do {
		                             		items = try self?.createFileProviderItems(from: snapshots.map(\.itemMetadata)) ?? []
		                             	} catch {
		                             		DDLogError("Working set onChange error: \(error)")
		                             		return
		                             	}
		                             	self?.handleWorkingSetUpdate(items: items)
		                             })
	}

	func handleWorkingSetUpdate(items: [FileProviderItem]) {
		let newWorkingSet = Set(items)
		let currentWorkingSetItemIdentifiers = Set(currentWorkingSetItems.map { $0.itemIdentifier })
		let newWorkingSetItemIdentifiers = Set(newWorkingSet.map { $0.itemIdentifier })
		let removedItems = Array(currentWorkingSetItemIdentifiers.subtracting(newWorkingSetItemIdentifiers))

		if !removedItems.isEmpty {
			notificator.removeItemsFromWorkingSet(with: removedItems)
		}
		if currentWorkingSetItems != newWorkingSet {
			notificator.updateWorkingSetItems(Array(newWorkingSet))
		}
		if !removedItems.isEmpty || currentWorkingSetItems != newWorkingSet {
			notificator.refreshWorkingSet()
		}
		currentWorkingSetItems = newWorkingSet
	}

	func createFileProviderItems(from metadataList: [ItemMetadata]) throws -> [FileProviderItem] {
		return try FileProviderItem.items(from: metadataList, domainIdentifier: domainIdentifier, uploadTaskManager: uploadTaskManager, cachedFileManager: cachedFileManager)
	}
}

/// GRDB observes only `Sendable` values, which `ItemMetadata` as a `Record` cannot be.
private struct WorkingSetItemSnapshot: Sendable, Equatable {
	let id: Int64?
	let name: String
	let type: CloudItemType
	let size: Int?
	let parentID: Int64
	let lastModifiedDate: Date?
	let statusCode: ItemStatus
	let isPlaceholderItem: Bool
	let isMaybeOutdated: Bool
	let favoriteRank: Int64?
	let tagData: Data?
	let lastEnumeratedAt: Date?

	init(_ itemMetadata: ItemMetadata) {
		self.id = itemMetadata.id
		self.name = itemMetadata.name
		self.type = itemMetadata.type
		self.size = itemMetadata.size
		self.parentID = itemMetadata.parentID
		self.lastModifiedDate = itemMetadata.lastModifiedDate
		self.statusCode = itemMetadata.statusCode
		self.isPlaceholderItem = itemMetadata.isPlaceholderItem
		self.isMaybeOutdated = itemMetadata.isMaybeOutdated
		self.favoriteRank = itemMetadata.favoriteRank
		self.tagData = itemMetadata.tagData
		self.lastEnumeratedAt = itemMetadata.lastEnumeratedAt
	}

	var itemMetadata: ItemMetadata {
		ItemMetadata(id: id, name: name, type: type, size: size, parentID: parentID, lastModifiedDate: lastModifiedDate, statusCode: statusCode, isPlaceholderItem: isPlaceholderItem, isCandidateForCacheCleanup: isMaybeOutdated, favoriteRank: favoriteRank, tagData: tagData, lastEnumeratedAt: lastEnumeratedAt)
	}
}
