//
//  ConcurrencyLimiter.swift
//  CryptomatorFileProvider
//
//  Created by Tobias Hagemann on 12.10.26.
//  Copyright © 2026 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import Foundation

/// Queues work beyond the limit in FIFO order instead of blocking a thread.
@MainActor
final class ConcurrencyLimiter {
	private let label: String
	private let maxConcurrentOperations: Int
	private var inFlightOperations = 0
	private var waitingAcquisitions = [CheckedContinuation<Void, Never>]()

	nonisolated init(label: String, maxConcurrentOperations: Int) {
		self.label = label
		self.maxConcurrentOperations = maxConcurrentOperations
	}

	func withPermit<Value>(_ work: @MainActor () async throws -> Value) async throws -> Value {
		await acquire()
		defer { release() }
		return try await work()
	}

	private func acquire() async {
		if inFlightOperations < maxConcurrentOperations {
			inFlightOperations += 1
		} else {
			await withCheckedContinuation { continuation in
				waitingAcquisitions.append(continuation)
			}
		}
		DDLogDebug("\(label): acquired permit, \(inFlightOperations) in flight")
	}

	private func release() {
		if waitingAcquisitions.isEmpty {
			inFlightOperations -= 1
		} else {
			waitingAcquisitions.removeFirst().resume()
		}
		DDLogDebug("\(label): released permit, \(inFlightOperations) in flight")
	}
}
