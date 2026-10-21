//
//  WorkflowFactory.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 28.05.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import FileProvider
import Foundation

@MainActor
struct WorkflowFactory {
	let provider: CloudProvider
	let uploadTaskManager: UploadTaskManager
	let cachedFileManager: CachedFileManager
	let itemMetadataManager: ItemMetadataManager
	let reparentTaskManager: ReparentTaskManager
	let deletionTaskManager: DeletionTaskManager
	let itemEnumerationTaskManager: ItemEnumerationTaskManager
	let downloadTaskManager: DownloadTaskManager
	let dependencyFactory = WorkflowDependencyFactory()
	private let uploadLimiter: ConcurrencyLimiter
	private let downloadLimiter: ConcurrencyLimiter
	/// Many sibling folders, as in a package, would otherwise be requested all at once.
	private let folderCreationLimiter = ConcurrencyLimiter(label: "FolderCreation", maxConcurrentOperations: 2)
	let domainIdentifier: NSFileProviderDomainIdentifier

	nonisolated init(provider: CloudProvider,
	                 uploadTaskManager: UploadTaskManager,
	                 cachedFileManager: CachedFileManager,
	                 itemMetadataManager: ItemMetadataManager,
	                 reparentTaskManager: ReparentTaskManager,
	                 deletionTaskManager: DeletionTaskManager,
	                 itemEnumerationTaskManager: ItemEnumerationTaskManager,
	                 downloadTaskManager: DownloadTaskManager,
	                 maxParallelUploads: Int,
	                 maxParallelDownloads: Int,
	                 domainIdentifier: NSFileProviderDomainIdentifier) {
		self.provider = provider
		self.uploadTaskManager = uploadTaskManager
		self.cachedFileManager = cachedFileManager
		self.itemMetadataManager = itemMetadataManager
		self.reparentTaskManager = reparentTaskManager
		self.deletionTaskManager = deletionTaskManager
		self.itemEnumerationTaskManager = itemEnumerationTaskManager
		self.downloadTaskManager = downloadTaskManager
		self.uploadLimiter = ConcurrencyLimiter(label: "Upload", maxConcurrentOperations: maxParallelUploads)
		self.downloadLimiter = ConcurrencyLimiter(label: "Download", maxConcurrentOperations: maxParallelDownloads)
		self.domainIdentifier = domainIdentifier
	}

	func createWorkflow(for deletionTask: DeletionTask) -> Workflow<Void> {
		let taskExecutor = DeletionTaskExecutor(provider: provider, itemMetadataManager: itemMetadataManager)
		let errorMapper = ErrorMapper<Void>()

		errorMapper.setNext(taskExecutor.eraseToAnyWorkflowMiddleware())

		let workflowDependency = dependencyFactory.createDependencies(for: deletionTask.cloudPath, lockType: .write)
		let middleware = wrapIntoDependencyMiddleware(errorMapper.eraseToAnyWorkflowMiddleware(), workflowDependency: workflowDependency)
		return Workflow(middleware: middleware, task: deletionTask)
	}

	func createWorkflow(for uploadTask: UploadTask) -> Workflow<FileProviderItem> {
		let onlineItemNameCollisionHandler = OnlineItemNameCollisionHandler<FileProviderItem>(itemMetadataManager: itemMetadataManager)
		let taskExecutor = UploadTaskExecutor(domainIdentifier: domainIdentifier, provider: provider, cachedFileManager: cachedFileManager, itemMetadataManager: itemMetadataManager, uploadTaskManager: uploadTaskManager, limiter: uploadLimiter)
		let errorMapper = ErrorMapper<FileProviderItem>()

		errorMapper.setNext(onlineItemNameCollisionHandler.eraseToAnyWorkflowMiddleware())
		onlineItemNameCollisionHandler.setNext(taskExecutor.eraseToAnyWorkflowMiddleware())

		let workflowDependency = dependencyFactory.createDependencies(for: uploadTask.cloudPath, lockType: .write)
		let middleware = wrapIntoDependencyMiddleware(errorMapper.eraseToAnyWorkflowMiddleware(), workflowDependency: workflowDependency)
		return Workflow(middleware: middleware, task: uploadTask)
	}

	func createWorkflow(for downloadTask: DownloadTask) -> Workflow<FileProviderItem> {
		let taskExecutor = DownloadTaskExecutor(domainIdentifier: domainIdentifier, provider: provider, itemMetadataManager: itemMetadataManager, cachedFileManager: cachedFileManager, downloadTaskManager: downloadTaskManager, limiter: downloadLimiter)
		let errorMapper = ErrorMapper<FileProviderItem>()

		errorMapper.setNext(taskExecutor.eraseToAnyWorkflowMiddleware())

		let workflowDependency = dependencyFactory.createDependencies(for: downloadTask.cloudPath, lockType: .read)
		let middleware = wrapIntoDependencyMiddleware(errorMapper.eraseToAnyWorkflowMiddleware(), workflowDependency: workflowDependency)
		return Workflow(middleware: middleware, task: downloadTask)
	}

	func createWorkflow(for reparentTask: ReparentTask) -> Workflow<FileProviderItem> {
		let onlineItemNameCollisionHandler = OnlineItemNameCollisionHandler<FileProviderItem>(itemMetadataManager: itemMetadataManager)
		let taskExecutor = ReparentTaskExecutor(domainIdentifier: domainIdentifier, provider: provider, reparentTaskManager: reparentTaskManager, itemMetadataManager: itemMetadataManager, cachedFileManager: cachedFileManager)
		let errorMapper = ErrorMapper<FileProviderItem>()

		errorMapper.setNext(onlineItemNameCollisionHandler.eraseToAnyWorkflowMiddleware())
		onlineItemNameCollisionHandler.setNext(taskExecutor.eraseToAnyWorkflowMiddleware())

		let sourceCloudPath = reparentTask.taskRecord.sourceCloudPath
		let targetCloudPath = reparentTask.taskRecord.targetCloudPath
		let workflowDependency = dependencyFactory.createDependencies(paths: [sourceCloudPath, targetCloudPath], lockType: .write)
		let middleware = wrapIntoDependencyMiddleware(errorMapper.eraseToAnyWorkflowMiddleware(), workflowDependency: workflowDependency)
		return Workflow(middleware: middleware, task: reparentTask)
	}

	func createWorkflow(for itemEnumerationTask: ItemEnumerationTask) -> Workflow<FileProviderItemList> {
		let deleteItemHelper = DeleteItemHelper(itemMetadataManager: itemMetadataManager, cachedFileManager: cachedFileManager)
		let taskExecutor = ItemEnumerationTaskExecutor(domainIdentifier: domainIdentifier, provider: provider, itemMetadataManager: itemMetadataManager, cachedFileManager: cachedFileManager, uploadTaskManager: uploadTaskManager, reparentTaskManager: reparentTaskManager, deletionTaskManager: deletionTaskManager, itemEnumerationTaskManager: itemEnumerationTaskManager, deleteItemHelper: deleteItemHelper)
		let errorMapper = ErrorMapper<FileProviderItemList>()

		errorMapper.setNext(taskExecutor.eraseToAnyWorkflowMiddleware())

		let workflowDependency = dependencyFactory.createDependencies(for: itemEnumerationTask.cloudPath, lockType: .read)
		let middleware = wrapIntoDependencyMiddleware(errorMapper.eraseToAnyWorkflowMiddleware(), workflowDependency: workflowDependency)

		return Workflow(middleware: middleware, task: itemEnumerationTask)
	}

	func createWorkflow(for folderCreationTask: FolderCreationTask) -> Workflow<FileProviderItem> {
		let onlineItemNameCollisionHandler = OnlineItemNameCollisionHandler<FileProviderItem>(itemMetadataManager: itemMetadataManager)
		let taskExecutor = FolderCreationTaskExecutor(domainIdentifier: domainIdentifier, provider: provider, itemMetadataManager: itemMetadataManager, limiter: folderCreationLimiter)
		let errorMapper = ErrorMapper<FileProviderItem>()
		errorMapper.setNext(onlineItemNameCollisionHandler.eraseToAnyWorkflowMiddleware())
		onlineItemNameCollisionHandler.setNext(taskExecutor.eraseToAnyWorkflowMiddleware())

		let workflowDependency = dependencyFactory.createDependencies(for: folderCreationTask.cloudPath, lockType: .write)
		let middleware = wrapIntoDependencyMiddleware(errorMapper.eraseToAnyWorkflowMiddleware(), workflowDependency: workflowDependency)

		return Workflow(middleware: middleware, task: folderCreationTask)
	}

	private func wrapIntoDependencyMiddleware<T>(_ middleware: AnyWorkflowMiddleware<T>, workflowDependency: WorkflowDependency) -> AnyWorkflowMiddleware<T> {
		let workflowDependency = WorkflowDependencyMiddleware<T>(dependency: workflowDependency)
		workflowDependency.setNext(middleware)
		return workflowDependency.eraseToAnyWorkflowMiddleware()
	}
}
