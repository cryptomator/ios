//
//  DownloadTaskExecutor.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 18.05.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import CryptomatorCloudAccessCore
import Dependencies
import Foundation

class DownloadTaskExecutor: WorkflowMiddleware {
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
	private let cachedFileManager: CachedFileManager
	private let downloadTaskManager: DownloadTaskManager
	private let provider: CloudProvider
	private let domainIdentifier: NSFileProviderDomainIdentifier
	private let limiter: ConcurrencyLimiter
	@Dependency(\.permissionProvider) private var permissionProvider

	init(domainIdentifier: NSFileProviderDomainIdentifier,
	     provider: CloudProvider,
	     itemMetadataManager: ItemMetadataManager,
	     cachedFileManager: CachedFileManager,
	     downloadTaskManager: DownloadTaskManager,
	     limiter: ConcurrencyLimiter) {
		self.domainIdentifier = domainIdentifier
		self.provider = provider
		self.itemMetadataManager = itemMetadataManager
		self.cachedFileManager = cachedFileManager
		self.downloadTaskManager = downloadTaskManager
		self.limiter = limiter
	}

	func execute(task: CloudTask) async throws -> FileProviderItem {
		guard let downloadTask = task as? DownloadTask else {
			throw WorkflowMiddlewareError.incompatibleCloudTask
		}
		let taskRecord = downloadTask.taskRecord
		defer {
			do {
				try downloadTaskManager.removeTaskRecord(taskRecord)
			} catch {
				DDLogError("Remove DownloadTask failed with error: \(error)")
			}
		}
		let downloadDestination = taskRecord.replaceExisting ? taskRecord.localURL.createCollisionURL() : taskRecord.localURL
		let itemMetadata = task.itemMetadata
		let cloudPath = task.cloudPath
		let cloudItemMetadata = try await limiter.withPermit {
			try await provider.downloadFile(from: cloudPath, to: downloadDestination, progress: nil, onTaskCreation: downloadTask.onURLSessionTaskCreation)
		}
		return try downloadPostProcessing(for: itemMetadata, lastModifiedDate: cloudItemMetadata.lastModifiedDate, localURL: taskRecord.localURL, downloadDestination: downloadDestination)
	}

	/**
	 Post-process the download.

	 Provides a uniform way of post-processing for overwriting and non-overwriting downloads.

	 In the case of a non-overwriting download, the `localURL` and the `downloadDestination`, can be the same `URL`.

	 - Parameter itemMetadata: The metadata of the item for which post-processing is performed.
	 - Parameter lastModifiedDate: (Optional) The date the downloaded version was last modified in the cloud, as reported by the download.
	 - Parameter localURL: The local URL where the downloaded file is located at the end.
	 - Parameter downloadDestination: The local URL to which the file was downloaded.
	 - Precondition: The passed `itemMetadata` has already been stored in the database, i.e. it has an `id`.
	 - Postcondition: The downloaded file is located at `localURL`.
	 - Postcondition: If `downloadDestination != localURL`, there is no file left at `downloadDestination`.
	 - Postcondition: The passed `itemMetadata` has the `statusCode == .isUploaded` in the database
	 - Postcondition: The `LocalCachedFileInfo` entry associated with the `metadata.id` has the passed `lastModifiedDate` and the passed `localURL` stored in the database.
	 - Returns: A `FileProviderItem` for the passed `metadata` with `statusCode == .isUploaded` and the flag `newestVersionLocallyCached` and the passed `localURL`.
	 */
	func downloadPostProcessing(for itemMetadata: ItemMetadata, lastModifiedDate: Date?, localURL: URL, downloadDestination: URL) throws -> FileProviderItem {
		if localURL != downloadDestination {
			try FileManager.default.removeItem(at: localURL)
			try FileManager.default.moveItem(at: downloadDestination, to: localURL)
		}
		itemMetadata.statusCode = .isUploaded
		try itemMetadataManager.updateMetadata(itemMetadata)
		try cachedFileManager.cacheLocalFileInfo(for: itemMetadata.id!, localURL: localURL, lastModifiedDate: lastModifiedDate)
		return FileProviderItem(metadata: itemMetadata, domainIdentifier: domainIdentifier, newestVersionLocallyCached: true, localURL: localURL)
	}
}
