//
//  OnlineItemNameCollisionHandler.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 25.05.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation
import Promises

class OnlineItemNameCollisionHandler<T>: WorkflowMiddleware {
	private let itemMetadataManager: ItemMetadataManager
	private var next: AnyWorkflowMiddleware<T>?

	init(itemMetadataManager: ItemMetadataManager) {
		self.itemMetadataManager = itemMetadataManager
	}

	func setNext(_ next: AnyWorkflowMiddleware<T>) {
		self.next = next
	}

	func getNext() throws -> AnyWorkflowMiddleware<T> {
		guard let nextMiddleware = next else {
			throw WorkflowMiddlewareError.missingMiddleware
		}
		return nextMiddleware
	}

	func execute(task: CloudTask) -> Promise<T> {
		let nextMiddleware: AnyWorkflowMiddleware<T>
		do {
			nextMiddleware = try getNext()
		} catch {
			return Promise(error)
		}
		return nextMiddleware.execute(task: task).recover { error -> Promise<T> in
			guard case CloudProviderError.itemAlreadyExists = error else {
				throw error
			}
			let refreshedTask = try self.cloudPathCollisionUpdate(for: task)
			return nextMiddleware.execute(task: refreshedTask)
		}
	}

	func cloudPathCollisionUpdate(for task: CloudTask) throws -> CloudTask {
		let collisionFreeCloudPath = task.cloudPath.createCollisionCloudPath()
		task.itemMetadata.name = collisionFreeCloudPath.lastPathComponent
		try itemMetadataManager.updateMetadata(task.itemMetadata)
		switch task {
		case let uploadTask as UploadTask:
			return uploadTask.with(cloudPath: collisionFreeCloudPath)
		case let downloadTask as DownloadTask:
			return downloadTask.with(cloudPath: collisionFreeCloudPath)
		case let folderCreationTask as FolderCreationTask:
			return folderCreationTask.with(cloudPath: collisionFreeCloudPath)
		case let itemEnumerationTask as ItemEnumerationTask:
			return itemEnumerationTask.with(cloudPath: collisionFreeCloudPath)
		case let deletionTask as DeletionTask:
			return deletionTask.with(cloudPath: collisionFreeCloudPath)
		case let reparentTask as ReparentTask:
			return reparentTask.with(cloudPath: collisionFreeCloudPath, taskRecord: reparentTask.taskRecord)
		default:
			throw FileProviderAdapterError.unsupportedItemType
		}
	}
}
