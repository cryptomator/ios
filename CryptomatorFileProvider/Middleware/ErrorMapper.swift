//
//  ErrorMapper.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 01.10.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import FileProvider
import Foundation
import Promises

class ErrorMapper<T>: WorkflowMiddleware {
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
		let nextMiddleware: AnyWorkflowMiddleware<T>
		do {
			nextMiddleware = try getNext()
		} catch {
			return Promise(error)
		}
		return nextMiddleware.execute(task: task).recover { error -> Promise<T> in
			return Promise(self.mapError(error))
		}
	}

	private func mapError(_ error: Error) -> Error {
		return error.toPresentableError()
	}
}

extension Error {
	func toPresentableError() -> Error {
		guard let cloudProviderError = self as? CloudProviderError else {
			return self
		}
		switch cloudProviderError {
		case .itemNotFound, .parentFolderDoesNotExist:
			return NSFileProviderError(.noSuchItem)
		case .itemAlreadyExists, .itemTypeMismatch:
			return NSFileProviderError(.filenameCollision)
		case .pageTokenInvalid:
			return NSFileProviderError(.syncAnchorExpired)
		case .quotaInsufficient:
			return NSFileProviderError(.insufficientQuota)
		case .unauthorized:
			return NSFileProviderError(.notAuthenticated)
		case .noInternetConnection:
			return NSFileProviderError(.serverUnreachable)
		}
	}
}
