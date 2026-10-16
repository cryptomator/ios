//
//  OneShotSignal.swift
//  CryptomatorCommonCore
//
//  Created by Tobias Hagemann on 15.10.26.
//  Copyright © 2026 Skymatic GmbH. All rights reserved.
//

import Foundation
import os

/// Settles at most once; the first `fulfill` or `reject` wins and every waiter, including a late one, receives that result. A cancelled waiter throws `CancellationError` without settling the signal.
public final class OneShotSignal<Value: Sendable>: Sendable {
	private struct State {
		var result: Result<Value, Error>?
		var waiters = [UUID: CheckedContinuation<Value, Error>]()
	}

	private let state = OSAllocatedUnfairLock(initialState: State())

	public init() {}

	public var value: Value {
		get async throws {
			let waiterID = UUID()
			return try await withTaskCancellationHandler {
				try await withCheckedThrowingContinuation { continuation in
					let result: Result<Value, Error>? = state.withLock { state in
						if let result = state.result {
							return result
						}
						if Task.isCancelled {
							return .failure(CancellationError())
						}
						state.waiters[waiterID] = continuation
						return nil
					}
					if let result {
						continuation.resume(with: result)
					}
				}
			} onCancel: {
				let continuation = state.withLock { $0.waiters.removeValue(forKey: waiterID) }
				continuation?.resume(throwing: CancellationError())
			}
		}
	}

	public func fulfill(_ value: Value) {
		settle(with: .success(value))
	}

	public func reject(_ error: Error) {
		settle(with: .failure(error))
	}

	private func settle(with result: Result<Value, Error>) {
		let waiters = state.withLock { state -> [CheckedContinuation<Value, Error>] in
			guard state.result == nil else {
				return []
			}
			state.result = result
			defer { state.waiters.removeAll() }
			return Array(state.waiters.values)
		}
		for waiter in waiters {
			waiter.resume(with: result)
		}
	}
}
