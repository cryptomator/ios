//
//  UploadTaskExecutor.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 18.05.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import CryptomatorCloudAccessCore
import Dependencies
import FileProvider
import Foundation
import Promises

class UploadTaskExecutor: WorkflowMiddleware {
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

	let provider: CloudProvider
	let cachedFileManager: CachedFileManager
	let itemMetadataManager: ItemMetadataManager
	let uploadTaskManager: UploadTaskManager
	let domainIdentifier: NSFileProviderDomainIdentifier
	let progressManager: ProgressManager
	@Dependency(\.permissionProvider) private var permissionProvider

	init(domainIdentifier: NSFileProviderDomainIdentifier,
	     provider: CloudProvider,
	     cachedFileManager: CachedFileManager,
	     itemMetadataManager: ItemMetadataManager,
	     uploadTaskManager: UploadTaskManager,
	     progressManager: ProgressManager = InMemoryProgressManager.shared) {
		self.domainIdentifier = domainIdentifier
		self.provider = provider
		self.cachedFileManager = cachedFileManager
		self.itemMetadataManager = itemMetadataManager
		self.uploadTaskManager = uploadTaskManager
		self.progressManager = progressManager
	}

	func execute(task: CloudTask) -> Promise<FileProviderItem> {
		guard let uploadTask = task as? UploadTask else {
			return Promise(WorkflowMiddlewareError.incompatibleCloudTask)
		}
		let itemMetadata = task.itemMetadata
		let localCachedFile: LocalCachedFileInfo?
		do {
			localCachedFile = try cachedFileManager.getLocalCachedFileInfo(for: itemMetadata)
		} catch {
			return Promise(error)
		}
		guard let localURL = localCachedFile?.localURL else {
			return Promise(NSFileProviderError(.noSuchItem))
		}

		let localFileSize: Int?
		do {
			let attributes = try FileManager.default.attributesOfItem(atPath: localURL.path)
			localFileSize = attributes[FileAttributeKey.size] as? Int
		} catch {
			return Promise(error)
		}

		let progress = Progress(totalUnitCount: 1)
		if let itemID = itemMetadata.id {
			progressManager.saveProgress(progress, for: NSFileProviderItemIdentifier(domainIdentifier: domainIdentifier, itemID: itemID))
		}
		progress.becomeCurrent(withPendingUnitCount: 1)
		let uploadPromise = provider.uploadFile(from: localURL,
		                                        to: itemMetadata.cloudPath,
		                                        replaceExisting: !itemMetadata.isPlaceholderItem,
		                                        onTaskCreation: { task in
		                                        	guard let task else {
		                                        		return
		                                        	}
		                                        	uploadTask.onURLSessionTaskCreation?(task)
		                                        })
		progress.resignCurrent()
		return uploadPromise.then { cloudItemMetadata in
			try self.uploadPostProcessing(taskItemMetadata: itemMetadata, cloudItemMetadata: cloudItemMetadata, localURL: localURL, localFileSizeBeforeUpload: localFileSize)
		}.recover { error -> FileProviderItem in
			try self.handleUploadError(error, taskItemMetadata: itemMetadata)
		}
	}

	/**
	 Post-process the upload.

	 Since some cloud providers (including WebDAV) cannot guarantee that the `CloudItemMetadata` supplied is the metadata of the uploaded version of the file, we must use the file size as a heuristic to verify this.

	 Otherwise, the user will be delivered an outdated file from the local cache even though there is a newer version in the cloud.

	 - Precondition: The passed `taskItemMetadata` has already been stored in the database, i.e. it has an `id`.
	 - Postcondition: `itemMetadata.statusCode == .isUploaded && itemMetadata.isPlaceholderItem == false`.
	 - Postcondition: If the file sizes (local & cloud) do not match, there is no more a local file under the `localURL` and no `LocalCachedFileInfo` entry for the `itemMetadata.id`.
	 - Postcondition: If the file sizes (local & cloud) match, the `lastModifiedDate` from the cloud was stored together with the `localURL` as `LocalCachedFileInfo` in the database for the `itemMetadata.id`.
	 */
	func uploadPostProcessing(taskItemMetadata: ItemMetadata, cloudItemMetadata: CloudItemMetadata, localURL: URL, localFileSizeBeforeUpload: Int?) throws -> FileProviderItem {
		taskItemMetadata.statusCode = .isUploaded
		taskItemMetadata.isPlaceholderItem = false
		taskItemMetadata.lastModifiedDate = cloudItemMetadata.lastModifiedDate
		taskItemMetadata.size = cloudItemMetadata.size
		try itemMetadataManager.updateMetadata(taskItemMetadata)
		try uploadTaskManager.removeTaskRecord(for: taskItemMetadata)
		if localFileSizeBeforeUpload == cloudItemMetadata.size {
			DDLogInfo("uploadPostProcessing: received cloudItemMetadata seem to be correct: localSize = \(localFileSizeBeforeUpload ?? -1); cloudItemSize = \(cloudItemMetadata.size ?? -1)")
			try cachedFileManager.cacheLocalFileInfo(for: taskItemMetadata.id!, localURL: localURL, lastModifiedDate: cloudItemMetadata.lastModifiedDate)
			return FileProviderItem(metadata: taskItemMetadata, domainIdentifier: domainIdentifier, newestVersionLocallyCached: true, localURL: localURL)
		} else {
			DDLogInfo("uploadPostProcessing: received cloudItemMetadata do not belong to the version that was uploaded - size differs!")
			try cachedFileManager.removeCachedFile(for: taskItemMetadata.id!)
			return FileProviderItem(metadata: taskItemMetadata, domainIdentifier: domainIdentifier)
		}
	}

	func handleUploadError(_ error: Error, taskItemMetadata: ItemMetadata) throws -> FileProviderItem {
		let convertedError = error.toPresentableError()
		try uploadTaskManager.updateTaskRecord(for: taskItemMetadata, with: convertedError as NSError)
		taskItemMetadata.statusCode = .uploadError
		try itemMetadataManager.updateMetadata(taskItemMetadata)
		let localCachedFileInfo = try cachedFileManager.getLocalCachedFileInfo(for: taskItemMetadata)
		let newestVersionLocallyCached = localCachedFileInfo?.isCurrentVersion(lastModifiedDateInCloud: taskItemMetadata.lastModifiedDate) ?? false
		let localURL = localCachedFileInfo?.localURL
		return FileProviderItem(metadata: taskItemMetadata, domainIdentifier: domainIdentifier, newestVersionLocallyCached: newestVersionLocallyCached, localURL: localURL, error: convertedError)
	}
}
