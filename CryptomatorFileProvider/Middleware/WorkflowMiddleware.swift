//
//  WorkflowMiddleware.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 18.05.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation

enum WorkflowMiddlewareError: Error {
	case missingMiddleware
	case incompatibleCloudTask
	case incompatibleMiddleware
}

/**
 A Workflow Middleware.

 Allows to wrap itself around the execution of a given task.
 A implementation of `execute(task:)` may look like the following way:
 ```swift
 func execute(task: CloudTask) async throws -> ReturnType {
   ... // some preprocessing logic (optional)
   let nextMiddleware = try getNext()
   let value = try await nextMiddleware.execute(task: task)
   ... // some postprocessing logic (optional)
   return value
 }
 ```
 */
@MainActor
protocol WorkflowMiddleware {
	associatedtype ReturnType
	associatedtype NextMiddleware: WorkflowMiddleware where NextMiddleware.ReturnType == ReturnType

	func getNext() throws -> NextMiddleware
	func setNext(_ next: NextMiddleware) throws
	func execute(task: CloudTask) async throws -> ReturnType
}

extension WorkflowMiddleware {
	func eraseToAnyWorkflowMiddleware() -> AnyWorkflowMiddleware<ReturnType> {
		AnyWorkflowMiddleware(self)
	}
}

class AnyWorkflowMiddleware<T>: WorkflowMiddleware {
	private let _execute: @MainActor (CloudTask) async throws -> T
	private let _getNext: @MainActor () throws -> AnyWorkflowMiddleware<T>
	private let _setNext: @MainActor (AnyWorkflowMiddleware<T>) throws -> Void

	func getNext() throws -> AnyWorkflowMiddleware<T> {
		try _getNext()
	}

	func setNext(_ next: AnyWorkflowMiddleware<T>) throws {
		try _setNext(next)
	}

	func execute(task: CloudTask) async throws -> T {
		try await _execute(task)
	}

	init<W: WorkflowMiddleware>(_ delegate: W) where W.ReturnType == T {
		self._execute = { task in
			return try await delegate.execute(task: task)
		}
		self._getNext = {
			let next = try delegate.getNext()
			return AnyWorkflowMiddleware<T>(next)
		}
		self._setNext = { next in
			guard let compatibleNextMiddleware = next as? W.NextMiddleware else {
				throw WorkflowMiddlewareError.incompatibleMiddleware
			}
			try delegate.setNext(compatibleNextMiddleware)
		}
	}
}
