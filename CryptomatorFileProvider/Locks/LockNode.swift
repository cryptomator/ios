//
//  LockNode.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 27.11.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import Foundation

class LockNode {
	private let lock: RWLock
	private let parent: LockNode?
	// path only for debug / log
	private let path: String

	init(path: String, lock: RWLock, parent: LockNode? = nil) {
		self.path = path
		self.lock = lock
		self.parent = parent
	}

	func readLock() {
		DDLogDebug("readLock \(path)(\(Unmanaged.passUnretained(self).toOpaque())) called")
		lock.readLock()
		DDLogDebug("readLock \(path)(\(Unmanaged.passUnretained(self).toOpaque())) done")
	}

	func writeLock() {
		DDLogDebug("writeLock \(path)(\(Unmanaged.passUnretained(self).toOpaque())) called")
		lock.writeLock()
		DDLogDebug("writeLock \(path)(\(Unmanaged.passUnretained(self).toOpaque())) done")
	}

	func unlock() {
		lock.unlock()
		parent?.unlock()
	}
}
