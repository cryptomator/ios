//
//  ErrorMapperTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 01.10.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import XCTest
@testable import CryptomatorFileProvider

@MainActor
class ErrorMapperTests: XCTestCase {
	func testMapCloudProviderErrors() async {
		await compareCloudProviderErrorMapping(for: .itemNotFound, expectedMappedError: NSFileProviderError(.noSuchItem) as Error)
		await compareCloudProviderErrorMapping(for: .itemAlreadyExists, expectedMappedError: NSFileProviderError(.filenameCollision) as Error)
		await compareCloudProviderErrorMapping(for: .parentFolderDoesNotExist, expectedMappedError: NSFileProviderError(.noSuchItem) as Error)
		await compareCloudProviderErrorMapping(for: .pageTokenInvalid, expectedMappedError: NSFileProviderError(.syncAnchorExpired) as Error)
		await compareCloudProviderErrorMapping(for: .quotaInsufficient, expectedMappedError: NSFileProviderError(.insufficientQuota) as Error)
		await compareCloudProviderErrorMapping(for: .unauthorized, expectedMappedError: NSFileProviderError(.notAuthenticated) as Error)
		await compareCloudProviderErrorMapping(for: .noInternetConnection, expectedMappedError: NSFileProviderError(.serverUnreachable) as Error)
	}

	func testCancellationErrorPassesThrough() async {
		await XCTAssertThrowsAsyncError(try await executeWorkflow(with: CancellationError())) { error in
			XCTAssert(error is CancellationError, "Expected CancellationError, got: \(error)")
		}
	}

	func compareErrorMapping(for error: Error, expectedMappedError: Error) async {
		await XCTAssertThrowsAsyncError(try await executeWorkflow(with: error), "Workflow succeeded, although expected mapped error: \(expectedMappedError) for original error: \(error)") { actualMappedError in
			XCTAssertEqual(expectedMappedError as NSError, actualMappedError as NSError)
		}
	}

	func compareCloudProviderErrorMapping(for error: CloudProviderError, expectedMappedError: Error) async {
		await compareErrorMapping(for: error, expectedMappedError: expectedMappedError)
	}

	func executeWorkflow(with error: Error) async throws {
		let workflowMock = WorkflowMiddlewareMock<Void> { _ in
			throw error
		}
		let errorMapper = ErrorMapper<Void>()
		errorMapper.setNext(workflowMock.eraseToAnyWorkflowMiddleware())
		try await errorMapper.execute(task: DummyTask())
	}

	// MARK: - Helpers

	private struct DummyTask: CloudTask {
		var itemMetadata: ItemMetadata {
			fatalError("not implemented")
		}

		var cloudPath: CloudPath {
			fatalError("not implemented")
		}
	}
}
