//
//  ReadingItemPathLockHandler.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 25.05.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation
import Promises
class ReadingItemPathLockHandler<T>: WorkflowMiddleware {
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
		let pathLock = LockManager.getPathLockForReading(at: cloudPath)
		let dataLock = LockManager.getDataLockForReading(at: cloudPath)
		return FileSystemLock.lockInOrder([pathLock, dataLock]).then {
			try self.getNext().execute(task: task)
		}.always {
			_ = FileSystemLock.unlockInOrder([dataLock, pathLock])
		}
	}
}
