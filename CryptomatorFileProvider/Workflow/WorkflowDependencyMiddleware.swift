//
//  WorkflowDependencyMiddleware.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 30.03.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation
import Promises

/**
 A middleware that makes sure to wait for a workflow's dependencies before executing.
 */
class WorkflowDependencyMiddleware<T>: WorkflowMiddleware {
	private var next: AnyWorkflowMiddleware<T>?
	private let workflowDependency: WorkflowDependency

	/**
	 Initializes a new workflow dependency middleware.

	 - Parameter dependency: The workflow dependency (leaf) nodes which belong to this workflow.
	 The next middleware is executed as soon as a lock is acquired for the dependency.
	 All leaf nodes are unlocked once the `CloudTask` associated with the workflow is completed (either successfully or with an error).
	 */
	init(dependency: WorkflowDependency) {
		self.workflowDependency = dependency
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
		return workflowDependency.awaitPreconditions().then {
			nextMiddleware.execute(task: task)
		}.then { value -> T in
			self.workflowDependency.notifyDependents(with: nil)
			return value
		}.catch { error in
			self.workflowDependency.notifyDependents(with: error)
		}
	}
}
