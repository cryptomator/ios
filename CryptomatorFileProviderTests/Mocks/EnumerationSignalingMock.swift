//
//  EnumerationSignalingMock.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 25.01.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorFileProvider
import FileProvider
import Foundation

// swiftlint:disable all
final class EnumerationSignalingMock: EnumerationSignaling {
	// MARK: - signalEnumerator

	var signalEnumeratorForCompletionHandlerCallsCount = 0
	var signalEnumeratorForCompletionHandlerCalled: Bool {
		signalEnumeratorForCompletionHandlerCallsCount > 0
	}

	var signalEnumeratorForCompletionHandlerReceivedArguments: (containerItemIdentifier: NSFileProviderItemIdentifier, completion: @Sendable (Error?) -> Void)?
	var signalEnumeratorForCompletionHandlerReceivedInvocations: [(containerItemIdentifier: NSFileProviderItemIdentifier, completion: @Sendable (Error?) -> Void)] = []
	var signalEnumeratorForCompletionHandlerClosure: ((NSFileProviderItemIdentifier, @escaping @Sendable (Error?) -> Void) -> Void)?

	func signalEnumerator(for containerItemIdentifier: NSFileProviderItemIdentifier, completionHandler completion: @escaping @Sendable (Error?) -> Void) {
		signalEnumeratorForCompletionHandlerCallsCount += 1
		signalEnumeratorForCompletionHandlerReceivedArguments = (containerItemIdentifier: containerItemIdentifier, completion: completion)
		signalEnumeratorForCompletionHandlerReceivedInvocations.append((containerItemIdentifier: containerItemIdentifier, completion: completion))
		signalEnumeratorForCompletionHandlerClosure?(containerItemIdentifier, completion)
	}
}

// swiftlint:enable all
