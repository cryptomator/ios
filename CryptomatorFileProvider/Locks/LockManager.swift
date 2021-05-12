//
//  LockManager.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 25.11.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation
import Promises

/**
 Provides a path-based locking mechanism as described by [Ritik Malhotra](https://people.eecs.berkeley.edu/~kubitron/courses/cs262a-F14/projects/reports/project6_report.pdf)

 Usage Example:
 ```
 let pathLock = LockManager.getPathLockForReading("/foo/bar/baz")
 let dataLock = LockManager.getDataLockForWriting("/foo/bar/baz")
 pathLock.lock().then {
 	datalock.lock()
 }.then {
 	// write to file
 }.always {
  	dataLock.unlock().then{
  	 	pathLock.unlock()
 	}
 }
 ```
 */
class LockManager {
	private static var pathLocks = [String: RWLock]()
	private static var dataLocks = [String: RWLock]()
	private static let queue = DispatchQueue(label: "LockManager Queue", qos: .userInitiated, attributes: .concurrent)
	private static let dictionaryQueue = DispatchQueue(label: "LockManager dicitionaryQueue")

	private static func readLock(locks: [RWLock], paths: [CloudPath]) -> Promise<LockNode> {
		return Promise<LockNode> { fulfill, _ in
			queue.async {
				var parentLockNode: LockNode?
				for (index, lock) in locks.enumerated() {
					let currentLockNode = LockNode(path: paths[index].path, lock: lock, parent: parentLockNode)
					parentLockNode = currentLockNode
					currentLockNode.readLock()
				}
				fulfill(parentLockNode!)
			}
		}
	}

	private static func writeLock(lock: RWLock, path: CloudPath) -> Promise<LockNode> {
		return Promise<LockNode> { fulfill, _ in
			queue.async {
				let lockNode = LockNode(path: path.path, lock: lock)
				lockNode.writeLock()
				fulfill(lockNode)
			}
		}
	}

	// MARK: - Path Locks

	public static func getPathLockForReading(at path: CloudPath) -> FileSystemLock {
		let partialPaths = path.getPartialCloudPaths()
		let pendingStartLockPromise = Promise<Void>.pending()
		let readLockPromise = pendingStartLockPromise.then {
			getPathLocks(for: partialPaths)
		}.then { locks in
			// pass partialPaths only for debug / log
			return readLock(locks: locks, paths: partialPaths)
		}
		return FileSystemLock(lockPromise: readLockPromise, startLockPromise: pendingStartLockPromise)
	}

	public static func getPathLockForWriting(at path: CloudPath) -> FileSystemLock {
		let pendingStartLockPromise = Promise<Void>.pending()
		let writeLockPromise = pendingStartLockPromise.then {
			getPathLock(for: path)
		}.then { lock in
			// pass path only for debug / log
			return writeLock(lock: lock, path: path)
		}
		return FileSystemLock(lockPromise: writeLockPromise, startLockPromise: pendingStartLockPromise)
	}

	// MARK: - Data Locks

	public static func getDataLockForReading(at path: CloudPath) -> FileSystemLock {
		let pendingStartLockPromise = Promise<Void>.pending()
		let readLockPromise = pendingStartLockPromise.then {
			getDataLock(for: path)
		}.then { lock in
			// pass path only for debug / log
			return readLock(locks: [lock], paths: [path])
		}
		return FileSystemLock(lockPromise: readLockPromise, startLockPromise: pendingStartLockPromise)
	}

	public static func getDataLockForWriting(at path: CloudPath) -> FileSystemLock {
		let pendingStartLockPromise = Promise<Void>.pending()
		let writeLockPromise = pendingStartLockPromise.then {
			getDataLock(for: path)
		}.then { lock in
			// pass path only for debug / log
			return writeLock(lock: lock, path: path)
		}
		return FileSystemLock(lockPromise: writeLockPromise, startLockPromise: pendingStartLockPromise)
	}

	// MARK: - Synchronized Dictionary Access

	private static func getPathLocks(for cloudPaths: [CloudPath]) -> Promise<[RWLock]> {
		return Promise<[RWLock]> { fulfill, _ in
			self.dictionaryQueue.async(flags: .barrier) {
				var pathLocksForCloudPath = [RWLock]()
				for cloudPath in cloudPaths {
					var pathLock = pathLocks[cloudPath.path]
					if pathLock == nil {
						pathLock = RWLock()
						pathLocks[cloudPath.path] = pathLock
					}
					pathLocksForCloudPath.append(pathLock!)
				}
				fulfill(pathLocksForCloudPath)
			}
		}
	}

	private static func getPathLock(for cloudPath: CloudPath) -> Promise<RWLock> {
		return Promise<RWLock> { fulfill, _ in
			self.dictionaryQueue.async(flags: .barrier) {
				var pathLock = pathLocks[cloudPath.path]
				if pathLock == nil {
					pathLock = RWLock()
					pathLocks[cloudPath.path] = pathLock
				}
				fulfill(pathLock!)
			}
		}
	}

	private static func getDataLock(for cloudPath: CloudPath) -> Promise<RWLock> {
		return Promise<RWLock> { fulfill, _ in
			self.dictionaryQueue.async(flags: .barrier) {
				var dataLock = dataLocks[cloudPath.path]
				if dataLock == nil {
					dataLock = RWLock()
					dataLocks[cloudPath.path] = dataLock
				}
				fulfill(dataLock!)
			}
		}
	}
}

extension CloudPath {
	/**
	 Get all partial cloud paths from the current cloud path.

	 Example:

	 `currentCloudPath = "/AAA/BBB/CCC/example.txt"`

	 This function returns the following cloud paths:

	 `["/", "/AAA/", "/AAA/BBB/", "/AAA/BBB/CCC/"]`

	 - Precondition: `startIndex > 0` (default: `startIndex = 1`).
	 - Postcondition: Returned `array.count > 0`.
	 */
	func getPartialCloudPaths(startIndex: Int = 1) -> [CloudPath] {
		precondition(startIndex > 0)
		var subCloudPaths = [CloudPath]()
		subCloudPaths.append(self)
		var cloudPath = self
		while cloudPath.pathComponents.count > startIndex {
			cloudPath = cloudPath.deletingLastPathComponent()
			subCloudPaths.append(cloudPath)
		}
		subCloudPaths.reverse()
		return subCloudPaths
	}
}
