//
//  DeletionTaskExecutor.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 18.05.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation

class DeletionTaskExecutor: WorkflowMiddleware {
	private var next: AnyWorkflowMiddleware<Void>?
	private let provider: CloudProvider
	private let itemMetadataManager: ItemMetadataManager

	init(provider: CloudProvider, itemMetadataManager: ItemMetadataManager) {
		self.provider = provider
		self.itemMetadataManager = itemMetadataManager
	}

	func execute(task: CloudTask) async throws {
		let itemMetadata = task.itemMetadata
		try await deleteItemInCloud(type: itemMetadata.type, at: task.cloudPath)
		try itemMetadataManager.removeItemMetadata(with: itemMetadata.id!)
	}

	private func deleteItemInCloud(type: CloudItemType, at cloudPath: CloudPath) async throws {
		switch type {
		case .file:
			try await provider.deleteFile(at: cloudPath)
		case .folder:
			try await provider.deleteFolder(at: cloudPath)
		default:
			throw FileProviderAdapterError.unsupportedItemType
		}
	}

	func setNext(_ next: AnyWorkflowMiddleware<Void>) {
		self.next = next
	}

	func getNext() throws -> AnyWorkflowMiddleware<Void> {
		guard let nextMiddleware = next else {
			throw WorkflowMiddlewareError.missingMiddleware
		}
		return nextMiddleware
	}
}
