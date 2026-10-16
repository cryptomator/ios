//
//  WorkflowDependencyMiddleware.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 30.03.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation

/**
 A middleware that runs the next middleware once every workflow it depends on has finished, whether that workflow succeeded or failed.

 It notifies its own dependents when it exits, even if its task failed or never ran.
 */
class WorkflowDependencyMiddleware<T>: WorkflowMiddleware {
	private var next: AnyWorkflowMiddleware<T>?
	private let workflowDependency: WorkflowDependency

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

	func execute(task: CloudTask) async throws -> T {
		defer { workflowDependency.notifyDependents() }
		let nextMiddleware = try getNext()
		try await workflowDependency.awaitPreconditions()
		return try await nextMiddleware.execute(task: task)
	}
}
