//
//  FileSystemLock.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 27.11.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Foundation
import Promises

class FileSystemLock {
	private let lockPromise: Promise<LockNode>
	private let startLockPromise: Promise<Void>

	init(lockPromise: Promise<LockNode>, startLockPromise: Promise<Void>) {
		self.lockPromise = lockPromise
		self.startLockPromise = startLockPromise
	}

	public func lock() -> Promise<Void> {
		startLockPromise.fulfill(())
		return lockPromise.then { _ in }
	}

	public func unlock() -> Promise<Void> {
		return lockPromise.then { lockNode in
			lockNode.unlock()
		}
	}

	public static func lockInOrder(_ locks: [FileSystemLock]) -> Promise<Void> {
		guard let firstLock = locks.first else {
			return Promise(())
		}
		return firstLock.lock().then { _ -> Promise<Void> in
			let remainingLocks = Array(locks.dropFirst())
			return lockInOrder(remainingLocks)
		}
	}

	public static func unlockInOrder(_ locks: [FileSystemLock]) -> Promise<Void> {
		guard let firstLock = locks.first else {
			return Promise(())
		}
		return firstLock.unlock().then { _ -> Promise<Void> in
			let remainingLocks = Array(locks.dropFirst())
			return unlockInOrder(remainingLocks)
		}
	}
}
