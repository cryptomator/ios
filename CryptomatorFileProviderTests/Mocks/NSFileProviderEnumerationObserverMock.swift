//
//  NSFileProviderEnumerationObserverMock.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 24.01.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import FileProvider
import Foundation

final class NSFileProviderEnumerationObserverMock: NSObject, NSFileProviderEnumerationObserver {
	// MARK: - didEnumerate

	var didEnumerateCallsCount = 0
	var didEnumerateCalled: Bool {
		didEnumerateCallsCount > 0
	}

	var didEnumerateReceivedUpdatedItems: [NSFileProviderItemProtocol]?
	var didEnumerateReceivedInvocations: [[NSFileProviderItemProtocol]] = []
	var didEnumerateClosure: (([NSFileProviderItemProtocol]) -> Void)?

	func didEnumerate(_ updatedItems: [NSFileProviderItemProtocol]) {
		didEnumerateCallsCount += 1
		didEnumerateReceivedUpdatedItems = updatedItems
		didEnumerateReceivedInvocations.append(updatedItems)
		didEnumerateClosure?(updatedItems)
	}

	// MARK: - finishEnumerating

	var finishEnumeratingUpToCallsCount = 0
	var finishEnumeratingUpToCalled: Bool {
		finishEnumeratingUpToCallsCount > 0
	}

	var finishEnumeratingUpToReceivedNextPage: NSFileProviderPage?
	var finishEnumeratingUpToReceivedInvocations: [NSFileProviderPage?] = []
	var finishEnumeratingUpToClosure: ((NSFileProviderPage?) -> Void)?

	func finishEnumerating(upTo nextPage: NSFileProviderPage?) {
		finishEnumeratingUpToCallsCount += 1
		finishEnumeratingUpToReceivedNextPage = nextPage
		finishEnumeratingUpToReceivedInvocations.append(nextPage)
		finishEnumeratingUpToClosure?(nextPage)
	}

	// MARK: - finishEnumeratingWithError

	var finishEnumeratingWithErrorCallsCount = 0
	var finishEnumeratingWithErrorCalled: Bool {
		finishEnumeratingWithErrorCallsCount > 0
	}

	var finishEnumeratingWithErrorReceivedError: Error?
	var finishEnumeratingWithErrorReceivedInvocations: [Error] = []
	var finishEnumeratingWithErrorClosure: ((Error) -> Void)?

	func finishEnumeratingWithError(_ error: Error) {
		finishEnumeratingWithErrorCallsCount += 1
		finishEnumeratingWithErrorReceivedError = error
		finishEnumeratingWithErrorReceivedInvocations.append(error)
		finishEnumeratingWithErrorClosure?(error)
	}
}
