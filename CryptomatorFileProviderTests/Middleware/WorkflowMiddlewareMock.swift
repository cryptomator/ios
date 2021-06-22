//
//  WorkflowMiddlewareMock.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 25.05.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation
import Promises
@testable import CryptomatorFileProvider

class WorkflowMiddlewareMock<T>: WorkflowMiddleware {
	private var next: AnyWorkflowMiddleware<T>?
	private let _execute: (CloudTask) -> Promise<T>

	init(execute: @escaping (CloudTask) -> Promise<T>) {
		self._execute = execute
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
		_execute(task)
	}
}
