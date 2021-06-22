//
//  CreatingOrDeletingItemPathLockHandler.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 25.05.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation
import Promises

class CreatingOrDeletingItemPathLockHandler<T>: WorkflowMiddleware {
	private var next: AnyWorkflowMiddleware<T>?

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
		let cloudPath = task.itemMetadata.cloudPath
		let pathLockForReading = LockManager.getPathLockForReading(at: cloudPath.deletingLastPathComponent())
		let dataLockForReading = LockManager.getDataLockForReading(at: cloudPath.deletingLastPathComponent())
		let pathLockForWriting = LockManager.getPathLockForWriting(at: cloudPath)
		let dataLockForWriting = LockManager.getDataLockForWriting(at: cloudPath)
		return FileSystemLock.lockInOrder([pathLockForReading, dataLockForReading, pathLockForWriting, dataLockForWriting]).then {
			try self.getNext().execute(task: task)
		}.always {
			_ = FileSystemLock.unlockInOrder([dataLockForWriting, pathLockForWriting, dataLockForReading, pathLockForReading])
		}
	}
}
