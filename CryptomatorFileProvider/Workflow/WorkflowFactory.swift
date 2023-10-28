//
//  WorkflowFactory.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 28.05.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Dependencies
import FileProvider
import Foundation

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
	let domainIdentifier: NSFileProviderDomainIdentifier
	@Dependency(\.permissionProvider) private var permissionProvider

	func createWorkflow(for deletionTask: DeletionTask) -> Workflow<Void> {
		let taskExecutor = DeletionTaskExecutor(provider: provider, itemMetadataManager: itemMetadataManager)
		let errorMapper = ErrorMapper<Void>()

		errorMapper.setNext(taskExecutor.eraseToAnyWorkflowMiddleware())

		let workflowDependency = dependencyFactory.createDependencies(for: deletionTask.cloudPath, lockType: .write)
		let middleware = wrapIntoDependencyMiddleware(errorMapper.eraseToAnyWorkflowMiddleware(), workflowDependency: workflowDependency)
		return Workflow(middleware: middleware, task: deletionTask, constraint: .unconstrained)
	}

	func createWorkflow(for uploadTask: UploadTask) -> Workflow<FileProviderItem> {
		let onlineItemNameCollisionHandler = OnlineItemNameCollisionHandler<FileProviderItem>(itemMetadataManager: itemMetadataManager)
		let taskExecutor = UploadTaskExecutor(domainIdentifier: domainIdentifier, provider: provider, cachedFileManager: cachedFileManager, itemMetadataManager: itemMetadataManager, uploadTaskManager: uploadTaskManager)
		let errorMapper = ErrorMapper<FileProviderItem>()

		errorMapper.setNext(onlineItemNameCollisionHandler.eraseToAnyWorkflowMiddleware())
		onlineItemNameCollisionHandler.setNext(taskExecutor.eraseToAnyWorkflowMiddleware())

		let workflowDependency = dependencyFactory.createDependencies(for: uploadTask.cloudPath, lockType: .write)
		let middleware = wrapIntoDependencyMiddleware(errorMapper.eraseToAnyWorkflowMiddleware(), workflowDependency: workflowDependency)
		return Workflow(middleware: middleware, task: uploadTask, constraint: .uploadConstrained)
	}

	func createWorkflow(for downloadTask: DownloadTask) -> Workflow<FileProviderItem> {
		let taskExecutor = DownloadTaskExecutor(domainIdentifier: domainIdentifier, provider: provider, itemMetadataManager: itemMetadataManager, cachedFileManager: cachedFileManager, downloadTaskManager: downloadTaskManager)
		let errorMapper = ErrorMapper<FileProviderItem>()

		errorMapper.setNext(taskExecutor.eraseToAnyWorkflowMiddleware())

		let workflowDependency = dependencyFactory.createDependencies(for: downloadTask.cloudPath, lockType: .read)
		let middleware = wrapIntoDependencyMiddleware(errorMapper.eraseToAnyWorkflowMiddleware(), workflowDependency: workflowDependency)
		return Workflow(middleware: middleware, task: downloadTask, constraint: .downloadConstrained)
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
		return Workflow(middleware: middleware, task: reparentTask, constraint: .unconstrained)
	}

	func createWorkflow(for itemEnumerationTask: ItemEnumerationTask) -> Workflow<FileProviderItemList> {
		let deleteItemHelper = DeleteItemHelper(itemMetadataManager: itemMetadataManager, cachedFileManager: cachedFileManager)
		let taskExecutor = ItemEnumerationTaskExecutor(domainIdentifier: domainIdentifier, provider: provider, itemMetadataManager: itemMetadataManager, cachedFileManager: cachedFileManager, uploadTaskManager: uploadTaskManager, reparentTaskManager: reparentTaskManager, deletionTaskManager: deletionTaskManager, itemEnumerationTaskManager: itemEnumerationTaskManager, deleteItemHelper: deleteItemHelper)
		let errorMapper = ErrorMapper<FileProviderItemList>()

		errorMapper.setNext(taskExecutor.eraseToAnyWorkflowMiddleware())

		let workflowDependency = dependencyFactory.createDependencies(for: itemEnumerationTask.cloudPath, lockType: .read)
		let middleware = wrapIntoDependencyMiddleware(errorMapper.eraseToAnyWorkflowMiddleware(), workflowDependency: workflowDependency)

		return Workflow(middleware: middleware, task: itemEnumerationTask, constraint: .unconstrained)
	}

	func createWorkflow(for folderCreationTask: FolderCreationTask) -> Workflow<FileProviderItem> {
		let onlineItemNameCollisionHandler = OnlineItemNameCollisionHandler<FileProviderItem>(itemMetadataManager: itemMetadataManager)
		let taskExecutor = FolderCreationTaskExecutor(domainIdentifier: domainIdentifier, provider: provider, itemMetadataManager: itemMetadataManager)
		let errorMapper = ErrorMapper<FileProviderItem>()
		errorMapper.setNext(onlineItemNameCollisionHandler.eraseToAnyWorkflowMiddleware())
		onlineItemNameCollisionHandler.setNext(taskExecutor.eraseToAnyWorkflowMiddleware())

		let workflowDependency = dependencyFactory.createDependencies(for: folderCreationTask.cloudPath, lockType: .write)
		let middleware = wrapIntoDependencyMiddleware(errorMapper.eraseToAnyWorkflowMiddleware(), workflowDependency: workflowDependency)

		return Workflow(middleware: middleware, task: folderCreationTask, constraint: .unconstrained)
	}

	private func wrapIntoDependencyMiddleware<T>(_ middleware: AnyWorkflowMiddleware<T>, workflowDependency: WorkflowDependency) -> AnyWorkflowMiddleware<T> {
		let workflowDependency = WorkflowDependencyMiddleware<T>(dependency: workflowDependency)
		workflowDependency.setNext(middleware)
		return workflowDependency.eraseToAnyWorkflowMiddleware()
	}
}

class MapTable<KeyType, ObjectType> where KeyType: AnyObject, ObjectType: AnyObject {
	private let mapTable: NSMapTable<KeyType, ObjectType>

	init(keyOptions: NSPointerFunctions.Options, valueOptions: NSPointerFunctions.Options) {
		self.mapTable = NSMapTable(keyOptions: keyOptions, valueOptions: valueOptions)
	}

	subscript(key: KeyType?) -> ObjectType? {
		get {
			mapTable.object(forKey: key)
		}
		set {
			mapTable.setObject(newValue, forKey: key)
		}
	}
}

extension MapTable where KeyType == NSString {
	subscript(key: String?) -> ObjectType? {
		get {
			mapTable.object(forKey: key as NSString?)
		}
		set {
			mapTable.setObject(newValue, forKey: key as NSString?)
		}
	}
}
