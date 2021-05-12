//
//  RWLock.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 27.11.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Foundation

final class RWLock {
	private var lock: pthread_rwlock_t

	init() {
		self.lock = pthread_rwlock_t()
		pthread_rwlock_init(&lock, nil)
	}

	deinit {
		pthread_rwlock_destroy(&lock)
	}

	func writeLock() {
		pthread_rwlock_wrlock(&lock)
	}

	func readLock() {
		pthread_rwlock_rdlock(&lock)
	}

	func unlock() {
		pthread_rwlock_unlock(&lock)
	}
}
