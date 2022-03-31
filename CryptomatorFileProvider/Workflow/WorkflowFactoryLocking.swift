//
//  WorkflowFactoryLocking.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 14.03.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation
import Promises

struct WorkflowFactoryLocking {
	let lockManager: LockManager
	let workflowFactory: WorkflowFactory

	func createWorkflow(for task: DeletionTask) -> Promise<Workflow<Void>> {
		let locks = lockManager.getCreatingOrDeletingItemLocks(for: task.cloudPath)
		return executeWithLocking(workflowFactory.createWorkflow(for: task),
		                          locks: locks)
	}

	func createWorkflow(for task: UploadTask) -> Promise<Workflow<FileProviderItem>> {
		let locks = lockManager.getCreatingOrDeletingItemLocks(for: task.cloudPath)

		return executeWithLocking(workflowFactory.createWorkflow(for: task),
		                          locks: locks)
	}

	func createWorkflow(for task: DownloadTask) -> Promise<Workflow<FileProviderItem>> {
		let locks = lockManager.createReadingItemLocks(for: task.cloudPath)
		return executeWithLocking(workflowFactory.createWorkflow(for: task),
		                          locks: locks)
	}

	func createWorkflow(for task: ReparentTask) -> Promise<Workflow<FileProviderItem>> {
		let locks = lockManager.createMovingItemLocks(sourceCloudPath: task.taskRecord.sourceCloudPath, targetCloudPath: task.taskRecord.targetCloudPath)
		return executeWithLocking(workflowFactory.createWorkflow(for: task),
		                          locks: locks)
	}

	func createWorkflow(for task: ItemEnumerationTask) -> Promise<Workflow<FileProviderItemList>> {
		let locks = lockManager.createReadingItemLocks(for: task.cloudPath)
		return executeWithLocking(workflowFactory.createWorkflow(for: task),
		                          locks: locks)
	}

	func createWorkflow(for task: FolderCreationTask) -> Promise<Workflow<FileProviderItem>> {
		let locks = lockManager.getCreatingOrDeletingItemLocks(for: task.cloudPath)
		return executeWithLocking(workflowFactory.createWorkflow(for: task),
		                          locks: locks)
	}

	private func executeWithLocking<T>(_ expression: @escaping @autoclosure () throws -> T, locks: [FileSystemLock]) -> Promise<T> {
		return FileSystemLock.lockInOrder(locks).then {
			try expression()
		}.always {
			_ = FileSystemLock.unlockInOrder(locks.reversed())
		}
	}
}
