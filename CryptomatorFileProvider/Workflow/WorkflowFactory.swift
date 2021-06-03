//
//  WorkflowFactory.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 28.05.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation
enum WorkflowFactory {
	static func createWorkflow(for deletionTask: DeletionTask, provider: CloudProvider, metadataManager: MetadataManager) throws -> Workflow<Void> {
		let pathLockMiddleware = CreatingOrDeletingItemPathLockHandler<Void>()
		let taskExecutor = DeletionTaskExecutor(provider: provider, metadataManager: metadataManager)
		pathLockMiddleware.setNext(taskExecutor.eraseToAnyWorkflowMiddleware())
		return Workflow(middleware: pathLockMiddleware.eraseToAnyWorkflowMiddleware(), task: deletionTask)
	}

	static func createWorkflow(for uploadTask: UploadTask, provider: CloudProvider, metadataManager: MetadataManager, cachedFileManager: CachedFileManager, uploadTaskManager: UploadTaskManager) throws -> Workflow<FileProviderItem> {
		let pathLockMiddleware = CreatingOrDeletingItemPathLockHandler<FileProviderItem>()
		let taskExecutor = UploadTaskExecutor(provider: provider, cachedFileManager: cachedFileManager, itemMetadataManager: metadataManager, uploadTaskManager: uploadTaskManager)
		pathLockMiddleware.setNext(taskExecutor.eraseToAnyWorkflowMiddleware())
		return Workflow(middleware: pathLockMiddleware.eraseToAnyWorkflowMiddleware(), task: uploadTask)
	}

	static func createWorkflow(for downloadTask: DownloadTask, provider: CloudProvider, metadataManager: MetadataManager, cachedFileManager: CachedFileManager) throws -> Workflow<FileProviderItem> {
		let pathLockMiddleware = ReadingItemPathLockHandler<FileProviderItem>()
		let taskExecutor = DownloadTaskExecutor(provider: provider, itemMetadataManager: metadataManager, cachedFileManager: cachedFileManager)
		pathLockMiddleware.setNext(taskExecutor.eraseToAnyWorkflowMiddleware())
		return Workflow(middleware: pathLockMiddleware.eraseToAnyWorkflowMiddleware(), task: downloadTask)
	}

	static func createWorkflow(for reparenTask: ReparentTask, provider: CloudProvider, metadataManager: MetadataManager, cachedFileManager: CachedFileManager, reparentTaskManager: ReparentTaskManager) throws -> Workflow<FileProviderItem> {
		let pathLockMiddleware = MovingItemPathLockHandler()
		let taskExecutor = ReparentTaskExecutor(provider: provider, reparentTaskManager: reparentTaskManager, metadataManager: metadataManager, cachedFileManager: cachedFileManager)
		pathLockMiddleware.setNext(taskExecutor.eraseToAnyWorkflowMiddleware())
		return Workflow(middleware: pathLockMiddleware.eraseToAnyWorkflowMiddleware(), task: reparenTask)
	}

	// swiftlint:disable:next function_parameter_count
	static func createWorkflow(for itemEnumerationTask: ItemEnumerationTask, provider: CloudProvider, metadataManager: MetadataManager, cachedFileManager: CachedFileManager, reparentTaskManager: ReparentTaskManager, uploadTaskManager: UploadTaskManager, deletionTaskManager: DeletionTaskManager) throws -> Workflow<FileProviderItemList> {
		let pathLockMiddleware = ReadingItemPathLockHandler<FileProviderItemList>()
		let deleteItemHelper = DeleteItemHelper(metadataManager: metadataManager, cachedFileManager: cachedFileManager)
		let taskExecutor = ItemEnumerationTaskExecutor(provider: provider, itemMetadataManager: metadataManager, cachedFileManager: cachedFileManager, uploadTaskManager: uploadTaskManager, reparentTaskManager: reparentTaskManager, deletionTaskManager: deletionTaskManager, deleteItemHelper: deleteItemHelper)
		pathLockMiddleware.setNext(taskExecutor.eraseToAnyWorkflowMiddleware())
		return Workflow(middleware: pathLockMiddleware.eraseToAnyWorkflowMiddleware(), task: itemEnumerationTask)
	}
}
