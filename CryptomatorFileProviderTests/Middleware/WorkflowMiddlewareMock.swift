//
//  WorkflowMiddlewareMock.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 25.05.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation
@testable import CryptomatorFileProvider

class WorkflowMiddlewareMock<T>: WorkflowMiddleware {
	private var next: AnyWorkflowMiddleware<T>?
	private let _execute: (CloudTask) async throws -> T

	init(execute: @escaping (CloudTask) async throws -> T) {
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

	func execute(task: CloudTask) async throws -> T {
		try await _execute(task)
	}
}
