//
//  WorkflowDependency.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 23.03.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import Foundation
import Promises

class WorkflowDependency<T>: WorkflowMiddleware {
	private var next: AnyWorkflowMiddleware<T>?
	private let parentTask: Promise<Void>
	private let dependencies: [WorkflowDependencyNode]

	/**
	 Initializes a new workflow dependency middleware.

	 - Parameter dependencies: The workflow dependency (leaf) nodes which belong to this workflow.
	 The next middleware is executed as soon as a lock is acquired for each dependency.
	 All leaf nodes are unlocked once the `CloudTask` associated with the workflow is completed (either successfully or with an error).
	 */
	init(dependencies: [WorkflowDependencyNode]) {
		self.dependencies = dependencies
		self.parentTask = all(dependencies.map { $0.isLocked }).then { _ -> Void in }
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
		return parentTask.then {
			nextMiddleware.execute(task: task)
		}.then { value -> T in
			self.dependencies.forEach { $0.unlock() }
			return value
		}.catch { error in
			self.dependencies.forEach { $0.unlock(with: error) }
		}
	}
}
