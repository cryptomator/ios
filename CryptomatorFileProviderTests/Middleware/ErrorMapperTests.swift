//
//  ErrorMapperTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 01.10.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Promises
import XCTest
@testable import CryptomatorFileProvider

class ErrorMapperTests: XCTestCase {
	func testMapCloudProviderErrors() throws {
		compareCloudProviderErrorMapping(for: .itemNotFound, expectedMappedError: NSFileProviderError(.noSuchItem) as Error)
		compareCloudProviderErrorMapping(for: .itemAlreadyExists, expectedMappedError: NSFileProviderError(.filenameCollision) as Error)
		compareCloudProviderErrorMapping(for: .parentFolderDoesNotExist, expectedMappedError: NSFileProviderError(.noSuchItem) as Error)
		compareCloudProviderErrorMapping(for: .pageTokenInvalid, expectedMappedError: NSFileProviderError(.syncAnchorExpired) as Error)
		compareCloudProviderErrorMapping(for: .quotaInsufficient, expectedMappedError: NSFileProviderError(.insufficientQuota) as Error)
		compareCloudProviderErrorMapping(for: .unauthorized, expectedMappedError: NSFileProviderError(.notAuthenticated) as Error)
		compareCloudProviderErrorMapping(for: .noInternetConnection, expectedMappedError: NSFileProviderError(.serverUnreachable) as Error)
	}

	func compareErrorMapping(for error: Error, expectedMappedError: Error) {
		let expectation = XCTestExpectation()
		executeWorkflow(with: error).then {
			XCTFail("Promise fulfilled, although expected mapped error: \(expectedMappedError) for original error: \(error)")
		}.catch { actualMappedError in
			XCTAssertEqual(expectedMappedError as NSError, actualMappedError as NSError)
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func compareCloudProviderErrorMapping(for error: CloudProviderError, expectedMappedError: Error) {
		compareErrorMapping(for: error, expectedMappedError: expectedMappedError)
	}

	func executeWorkflow(with error: Error) -> Promise<Void> {
		let workflowMock = WorkflowMiddlewareMock<Void> { _ in
			return Promise(error)
		}
		let errorMapper = ErrorMapper<Void>()
		errorMapper.setNext(workflowMock.eraseToAnyWorkflowMiddleware())
		return errorMapper.execute(task: DummyTask())
	}

	private struct DummyTask: CloudTask {
		var itemMetadata: ItemMetadata {
			fatalError("not implemented")
		}
	}
}
