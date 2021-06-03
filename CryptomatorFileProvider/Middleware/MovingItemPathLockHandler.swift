//
//  MovingItemPathLockHandler.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 18.05.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation
import Promises

class MovingItemPathLockHandler: WorkflowMiddleware {
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

	func execute(task: CloudTask) -> Promise<FileProviderItem> {
		guard let reparentTask = task as? ReparentTask else {
			return Promise(WorkflowMiddlewareError.incompatibleCloudTask)
		}
		let sourceCloudPath = reparentTask.taskRecord.sourceCloudPath
		let targetCloudPath = reparentTask.taskRecord.targetCloudPath

		let oldPathLockForReading = LockManager.getPathLockForReading(at: sourceCloudPath.deletingLastPathComponent())
		let oldDataLockForReading = LockManager.getDataLockForReading(at: sourceCloudPath.deletingLastPathComponent())
		let newPathLockForReading = LockManager.getPathLockForReading(at: targetCloudPath.deletingLastPathComponent())
		let newDataLockForReading = LockManager.getDataLockForReading(at: targetCloudPath.deletingLastPathComponent())
		let oldPathLockForWriting = LockManager.getPathLockForWriting(at: sourceCloudPath)
		let oldDataLockForWriting = LockManager.getDataLockForWriting(at: sourceCloudPath)
		let newPathLockForWriting = LockManager.getPathLockForWriting(at: targetCloudPath)
		let newDataLockForWriting = LockManager.getDataLockForWriting(at: targetCloudPath)
		return FileSystemLock.lockInOrder([
			oldPathLockForReading,
			oldDataLockForReading,
			newPathLockForReading,
			newDataLockForReading,
			oldPathLockForWriting,
			oldDataLockForWriting,
			newPathLockForWriting,
			newDataLockForWriting
		]).then {
			try self.getNext().execute(task: task)
		}.always {
			_ = FileSystemLock.unlockInOrder([
				newDataLockForWriting,
				newPathLockForWriting,
				oldDataLockForWriting,
				oldPathLockForWriting,
				newDataLockForReading,
				newPathLockForReading,
				oldDataLockForReading,
				oldPathLockForReading
			])
		}
	}
}
