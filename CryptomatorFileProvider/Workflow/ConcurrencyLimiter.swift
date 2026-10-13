//
//  ConcurrencyLimiter.swift
//  CryptomatorFileProvider
//
//  Created by Tobias Hagemann on 12.10.26.
//  Copyright © 2026 Skymatic GmbH. All rights reserved.
//

import Foundation
import Promises

/// Queues work beyond the limit instead of blocking a thread, because the workflows run on the main queue. That queue also
/// serializes every access, so the state needs no lock.
class ConcurrencyLimiter {
	private var availablePermits: Int
	private var waitingAcquisitions = [Promise<Void>]()

	init(maxConcurrentOperations: Int) {
		self.availablePermits = maxConcurrentOperations
	}

	func withPermit<Value>(_ work: @escaping () -> Promise<Value>) -> Promise<Value> {
		return acquire().then {
			work()
		}.always {
			self.release()
		}
	}

	private func acquire() -> Promise<Void> {
		if availablePermits > 0 {
			availablePermits -= 1
			return Promise(())
		}
		let acquisition = Promise<Void>.pending()
		waitingAcquisitions.append(acquisition)
		return acquisition
	}

	private func release() {
		guard !waitingAcquisitions.isEmpty else {
			availablePermits += 1
			return
		}
		waitingAcquisitions.removeFirst().fulfill(())
	}
}
