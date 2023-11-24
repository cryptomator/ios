//
//  FolderCreationTaskExecutor.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 07.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import FileProvider
import Foundation
import Promises

class FolderCreationTaskExecutor: WorkflowMiddleware {
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

	private let itemMetadataManager: ItemMetadataManager
	private let provider: CloudProvider
	private let domainIdentifier: NSFileProviderDomainIdentifier

	init(domainIdentifier: NSFileProviderDomainIdentifier,
	     provider: CloudProvider,
	     itemMetadataManager: ItemMetadataManager) {
		self.domainIdentifier = domainIdentifier
		self.provider = provider
		self.itemMetadataManager = itemMetadataManager
	}

	/**
	 Creates a folder in the cloud.

	 - Precondition: The metadata is stored in the database as `PlaceholderItem`.
	 - Precondition: The passed item is a folder.
	 - Postcondition: The folder was created in the cloud.
	 - Postcondition: The `ItemMetadata` entry associated with the created folder has the `statusCode == .isUploaded` and `isPlaceholderItem == false` in the database.
	 */
	func execute(task: CloudTask) -> Promise<FileProviderItem> {
		guard task is FolderCreationTask else {
			return Promise(WorkflowMiddlewareError.incompatibleCloudTask)
		}
		let itemMetadata = task.itemMetadata

		assert(itemMetadata.isPlaceholderItem)
		assert(itemMetadata.id != nil)
		assert(itemMetadata.type == .folder)

		return provider.createFolder(at: itemMetadata.cloudPath).then { [domainIdentifier, itemMetadataManager] _ -> FileProviderItem in
			itemMetadata.statusCode = .isUploaded
			itemMetadata.isPlaceholderItem = false
			try itemMetadataManager.updateMetadata(itemMetadata)
			return FileProviderItem(metadata: itemMetadata,
			                        domainIdentifier: domainIdentifier,
			                        newestVersionLocallyCached: true)
		}
	}
}
