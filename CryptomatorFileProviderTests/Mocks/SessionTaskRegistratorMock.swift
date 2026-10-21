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
import os

// swiftlint:disable all
@dynamicMemberLookup
final class SessionTaskRegistratorMock: SessionTaskRegistrator {
	struct State {
		var registerForItemWithIdentifierThrowableError: Error?
		var registerForItemWithIdentifierCallsCount = 0
		var registerForItemWithIdentifierReceivedArguments: (task: URLSessionTask, identifier: NSFileProviderItemIdentifier)?
		var registerForItemWithIdentifierReceivedInvocations: [(task: URLSessionTask, identifier: NSFileProviderItemIdentifier)] = []
		var registerForItemWithIdentifierClosure: (@Sendable (URLSessionTask, NSFileProviderItemIdentifier) async throws -> Void)?
	}

	private let state = OSAllocatedUnfairLock(initialState: State())

	subscript<T>(dynamicMember keyPath: WritableKeyPath<State, T>) -> T {
		get { state.withLockUnchecked { $0[keyPath: keyPath] } }
		set { state.withLockUnchecked { $0[keyPath: keyPath] = newValue } }
	}

	// MARK: - register

	var registerForItemWithIdentifierCalled: Bool {
		self.registerForItemWithIdentifierCallsCount > 0
	}

	func register(_ task: URLSessionTask, forItemWithIdentifier identifier: NSFileProviderItemIdentifier) async throws {
		let closure = try state.withLockUnchecked { state in
			if let error = state.registerForItemWithIdentifierThrowableError {
				throw error
			}
			state.registerForItemWithIdentifierCallsCount += 1
			state.registerForItemWithIdentifierReceivedArguments = (task: task, identifier: identifier)
			state.registerForItemWithIdentifierReceivedInvocations.append((task: task, identifier: identifier))
			return state.registerForItemWithIdentifierClosure
		}
		try await closure?(task, identifier)
	}
}

// swiftlint:enable all
