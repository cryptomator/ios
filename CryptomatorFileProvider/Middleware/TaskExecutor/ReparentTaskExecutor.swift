//
//  ReparentTaskExecutor.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 18.05.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Dependencies
import FileProvider
import Foundation
import Promises

class ReparentTaskExecutor: WorkflowMiddleware {
	private var next: AnyWorkflowMiddleware<FileProviderItem>?

	func setNext(_ next: AnyWorkflowMiddleware<FileProviderItem>) {
		self.next = next
	}

	func getNext() throws -> AnyWorkflowMiddleware<FileProviderItem> {
		guard let nextMiddleware = next else {
			throw WorkflowMiddlewareError.missingMiddleware
		}
		return nextMiddleware
	}

	private let provider: CloudProvider
	private let reparentTaskManager: ReparentTaskManager
	private let itemMetadataManager: ItemMetadataManager
	private let cachedFileManager: CachedFileManager
	private let domainIdentifier: NSFileProviderDomainIdentifier
	@Dependency(\.permissionProvider) private var permissionProvider

	init(domainIdentifier: NSFileProviderDomainIdentifier,
	     provider: CloudProvider,
	     reparentTaskManager: ReparentTaskManager,
	     itemMetadataManager: ItemMetadataManager,
	     cachedFileManager: CachedFileManager) {
		self.domainIdentifier = domainIdentifier
		self.provider = provider
		self.reparentTaskManager = reparentTaskManager
		self.itemMetadataManager = itemMetadataManager
		self.cachedFileManager = cachedFileManager
	}

	/**
	 Moves the item in the cloud.

	 - Precondition: The passed task is a `ReparentTask`.
	 - Precondition: The `ItemMetadata` associated with the `identifier` exists in the database.
	 - Precondition: The `ReparentTask` associated with the `identifier` exists in the database.
	 - Postcondition: The item in the cloud has the same parent folder and name as in the database.
	 - Postcondition: The `ItemMetadata` entry associated with the `identifier` has the `statusCode == .isUploaded`.
	 - Postcondition: The `ItemMetadata` entry associated with the `identifier` has the `statusCode == .isUploaded`.
	 */
	func execute(task: CloudTask) -> Promise<FileProviderItem> {
		guard let reparentTask = task as? ReparentTask else {
			return Promise(WorkflowMiddlewareError.incompatibleCloudTask)
		}
		return moveItemInCloud(reparentTask: reparentTask).then { _ -> FileProviderItem in
			let itemMetadata = reparentTask.itemMetadata
			itemMetadata.statusCode = .isUploaded
			try self.itemMetadataManager.updateMetadata(itemMetadata)
			let localCachedFileInfo = try self.cachedFileManager.getLocalCachedFileInfo(for: itemMetadata)
			let newestVersionLocallyCached = localCachedFileInfo?.isCurrentVersion(lastModifiedDateInCloud: itemMetadata.lastModifiedDate) ?? false
			try self.reparentTaskManager.removeTaskRecord(reparentTask.taskRecord)
			return FileProviderItem(metadata: itemMetadata, domainIdentifier: self.domainIdentifier, newestVersionLocallyCached: newestVersionLocallyCached)
		}
	}

	private func moveItemInCloud(reparentTask: ReparentTask) -> Promise<Void> {
		switch reparentTask.itemMetadata.type {
		case .file:
			return provider.moveFile(from: reparentTask.taskRecord.sourceCloudPath, to: reparentTask.taskRecord.targetCloudPath)
		case .folder:
			return provider.moveFolder(from: reparentTask.taskRecord.sourceCloudPath, to: reparentTask.taskRecord.targetCloudPath)
		default:
			return Promise(FileProviderAdapterError.unsupportedItemType)
		}
	}
}
