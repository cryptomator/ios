//
//  WorkingSetObserver.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 21.01.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import Dependencies
import FileProvider
import Foundation
import GRDB

protocol WorkingSetObserving {
	func startObservation()
}

class WorkingSetObserver: WorkingSetObserving {
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
			try ItemMetadata.filterWorkingSet().fetchAll(db)
		}.removeDuplicates()
		observer = observation.start(in: database,
		                             onError: { error in
		                             	DDLogError("Working set startObservation error: \(error)")
		                             },
		                             onChange: { [weak self] (metadataList: [ItemMetadata]) in
		                             	let items: [FileProviderItem]
		                             	do {
		                             		items = try self?.createFileProviderItems(from: metadataList) ?? []
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
		let uploadTasks = try uploadTaskManager.getTaskRecords(for: metadataList)
		let items = try metadataList.enumerated().map { index, metadata -> FileProviderItem in
			let localCachedFileInfo = try cachedFileManager.getLocalCachedFileInfo(for: metadata)
			let newestVersionLocallyCached = localCachedFileInfo?.isCurrentVersion(lastModifiedDateInCloud: metadata.lastModifiedDate) ?? false
			let localURL = localCachedFileInfo?.localURL
			return FileProviderItem(metadata: metadata, domainIdentifier: domainIdentifier, newestVersionLocallyCached: newestVersionLocallyCached, localURL: localURL, error: uploadTasks[index]?.failedWithError)
		}
		return items
	}
}
