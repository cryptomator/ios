//
//  SessionTaskRegistratorMock.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 11.01.23.
//  Copyright © 2023 Skymatic GmbH. All rights reserved.
//

import CryptomatorFileProvider
import FileProvider
import Foundation

// swiftlint:disable all
final class SessionTaskRegistratorMock: SessionTaskRegistrator {
	// MARK: - register

	var registerForItemWithIdentifierCompletionHandlerCallsCount = 0
	var registerForItemWithIdentifierCompletionHandlerCalled: Bool {
		registerForItemWithIdentifierCompletionHandlerCallsCount > 0
	}

	var registerForItemWithIdentifierCompletionHandlerReceivedArguments: (task: SessionTask, identifier: NSFileProviderItemIdentifier, completion: (Error?) -> Void)?
	var registerForItemWithIdentifierCompletionHandlerReceivedInvocations: [(task: SessionTask, identifier: NSFileProviderItemIdentifier, completion: (Error?) -> Void)] = []
	var registerForItemWithIdentifierCompletionHandlerClosure: ((SessionTask, NSFileProviderItemIdentifier, @escaping (Error?) -> Void) -> Void)?

	func register(_ task: SessionTask, forItemWithIdentifier identifier: NSFileProviderItemIdentifier, completionHandler completion: @escaping (Error?) -> Void) {
		registerForItemWithIdentifierCompletionHandlerCallsCount += 1
		registerForItemWithIdentifierCompletionHandlerReceivedArguments = (task: task, identifier: identifier, completion: completion)
		registerForItemWithIdentifierCompletionHandlerReceivedInvocations.append((task: task, identifier: identifier, completion: completion))
		registerForItemWithIdentifierCompletionHandlerClosure?(task, identifier, completion)
	}
}

// swiftlint:enable all
