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
			let collisionFreeCloudPath = task.itemMetadata.cloudPath.createCollisionCloudPath()
			try self.cloudPathCollisionUpdate(with: collisionFreeCloudPath, itemMetadata: task.itemMetadata)
			return nextMiddleware.execute(task: task)
		}
	}

	func cloudPathCollisionUpdate(with collisionFreeCloudPath: CloudPath, itemMetadata: ItemMetadata) throws {
		itemMetadata.name = collisionFreeCloudPath.lastPathComponent
		itemMetadata.cloudPath = collisionFreeCloudPath
		try itemMetadataManager.updateMetadata(itemMetadata)
	}
}
