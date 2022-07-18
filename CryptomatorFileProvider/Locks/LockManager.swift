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
 	dataLock.lock()
 }.then {
 	// write to file
 }.always {
  	dataLock.unlock().then{
 		pathLock.unlock()
 	}
 }
 ```

 Alternatively, use the convenience method to lock/unlock multiple locks in order:
 ```
 FileSystemLock.lockInOrder([pathLock, dataLock]).then {
 	// write to file
 }.always {
 	_ = FileSystemLock.unlockInOrder([dataLock, pathLock])
 }
 ```
 */
class LockManager {
	static let local = LockManager()
	private var pathLocks = MapTable<NSString, RWLock>(keyOptions: .copyIn, valueOptions: .weakMemory)
	private var dataLocks = MapTable<NSString, RWLock>(keyOptions: .copyIn, valueOptions: .weakMemory)
	private let queue = DispatchQueue(label: "LockManager Queue", qos: .userInitiated, attributes: .concurrent)
	private let dictionaryQueue = DispatchQueue(label: "LockManager dictionaryQueue")

	private func readLock(locks: [RWLock], paths: [CloudPath]) -> Promise<LockNode> {
		return Promise<LockNode> { fulfill, _ in
			self.queue.async {
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

	private func writeLock(lock: RWLock, path: CloudPath) -> Promise<LockNode> {
		return Promise<LockNode> { fulfill, _ in
			self.queue.async {
				let lockNode = LockNode(path: path.path, lock: lock)
				lockNode.writeLock()
				fulfill(lockNode)
			}
		}
	}

	// MARK: - Path Locks

	public func getPathLockForReading(at path: CloudPath) -> FileSystemLock {
		let partialPaths = path.getPartialCloudPaths()
		let pendingStartLockPromise = Promise<Void>.pending()
		let readLockPromise = pendingStartLockPromise.then {
			self.getPathLocks(for: partialPaths)
		}.then { locks in
			// pass partialPaths only for debug / log
			return self.readLock(locks: locks, paths: partialPaths)
		}
		return FileSystemLock(lockPromise: readLockPromise, startLockPromise: pendingStartLockPromise)
	}

	public func getPathLockForWriting(at path: CloudPath) -> FileSystemLock {
		let pendingStartLockPromise = Promise<Void>.pending()
		let writeLockPromise = pendingStartLockPromise.then {
			self.getPathLock(for: path)
		}.then { lock in
			// pass path only for debug / log
			return self.writeLock(lock: lock, path: path)
		}
		return FileSystemLock(lockPromise: writeLockPromise, startLockPromise: pendingStartLockPromise)
	}

	// MARK: - Data Locks

	public func getDataLockForReading(at path: CloudPath) -> FileSystemLock {
		let pendingStartLockPromise = Promise<Void>.pending()
		let readLockPromise = pendingStartLockPromise.then {
			self.getDataLock(for: path)
		}.then { lock in
			// pass path only for debug / log
			return self.readLock(locks: [lock], paths: [path])
		}
		return FileSystemLock(lockPromise: readLockPromise, startLockPromise: pendingStartLockPromise)
	}

	public func getDataLockForWriting(at path: CloudPath) -> FileSystemLock {
		let pendingStartLockPromise = Promise<Void>.pending()
		let writeLockPromise = pendingStartLockPromise.then {
			self.getDataLock(for: path)
		}.then { lock in
			// pass path only for debug / log
			return self.writeLock(lock: lock, path: path)
		}
		return FileSystemLock(lockPromise: writeLockPromise, startLockPromise: pendingStartLockPromise)
	}

	// MARK: - Synchronized Dictionary Access

	private func getPathLocks(for cloudPaths: [CloudPath]) -> Promise<[RWLock]> {
		return Promise<[RWLock]> { fulfill, _ in
			self.dictionaryQueue.async(flags: .barrier) {
				var pathLocksForCloudPath = [RWLock]()
				for cloudPath in cloudPaths {
					var pathLock = self.pathLocks[cloudPath.path]
					if pathLock == nil {
						print("create new pathLock for: \(cloudPath.path)")
						pathLock = RWLock()
						self.pathLocks[cloudPath.path] = pathLock
					}
					pathLocksForCloudPath.append(pathLock!)
				}
				fulfill(pathLocksForCloudPath)
			}
		}
	}

	private func getPathLock(for cloudPath: CloudPath) -> Promise<RWLock> {
		return Promise<RWLock> { fulfill, _ in
			self.dictionaryQueue.async(flags: .barrier) {
				var pathLock = self.pathLocks[cloudPath.path]
				if pathLock == nil {
					pathLock = RWLock()
					self.pathLocks[cloudPath.path] = pathLock
				}
				fulfill(pathLock!)
			}
		}
	}

	private func getDataLock(for cloudPath: CloudPath) -> Promise<RWLock> {
		return Promise<RWLock> { fulfill, _ in
			self.dictionaryQueue.async(flags: .barrier) {
				var dataLock = self.dataLocks[cloudPath.path]
				if dataLock == nil {
					dataLock = RWLock()
					self.dataLocks[cloudPath.path] = dataLock
				}
				fulfill(dataLock!)
			}
		}
	}
}

extension LockManager {
	func getCreatingOrDeletingItemLocks(for cloudPath: CloudPath) -> [FileSystemLock] {
		let pathLockForReading = getPathLockForReading(at: cloudPath.deletingLastPathComponent())
		let dataLockForReading = getDataLockForReading(at: cloudPath.deletingLastPathComponent())
		let pathLockForWriting = getPathLockForWriting(at: cloudPath)
		let dataLockForWriting = getDataLockForWriting(at: cloudPath)
		return [pathLockForReading, dataLockForReading, pathLockForWriting, dataLockForWriting]
	}
}

extension LockManager {
	func createMovingItemLocks(sourceCloudPath: CloudPath, targetCloudPath: CloudPath) -> [FileSystemLock] {
		let oldPathLockForReading = getPathLockForReading(at: sourceCloudPath.deletingLastPathComponent())
		let oldDataLockForReading = getDataLockForReading(at: sourceCloudPath.deletingLastPathComponent())
		let newPathLockForReading = getPathLockForReading(at: targetCloudPath.deletingLastPathComponent())
		let newDataLockForReading = getDataLockForReading(at: targetCloudPath.deletingLastPathComponent())
		let oldPathLockForWriting = getPathLockForWriting(at: sourceCloudPath)
		let oldDataLockForWriting = getDataLockForWriting(at: sourceCloudPath)
		let newPathLockForWriting = getPathLockForWriting(at: targetCloudPath)
		let newDataLockForWriting = getDataLockForWriting(at: targetCloudPath)

		return [
			oldPathLockForReading,
			oldDataLockForReading,
			newPathLockForReading,
			newDataLockForReading,
			oldPathLockForWriting,
			oldDataLockForWriting,
			newPathLockForWriting,
			newDataLockForWriting
		]
	}
}

extension LockManager {
	func createReadingItemLocks(for cloudPath: CloudPath) -> [FileSystemLock] {
		let pathLock = getPathLockForReading(at: cloudPath)
		let dataLock = getDataLockForReading(at: cloudPath)
		return [pathLock, dataLock]
	}
}

extension CloudPath {
	/**
	 Get all partial cloud paths from the current cloud path.

	 Example:

	 `currentCloudPath = "/AAA/BBB/CCC/example.txt"`

	 This function returns the following cloud paths:

	 `["/", "/AAA/", "/AAA/BBB/", "/AAA/BBB/CCC/", "/AAA/BBB/CCC/example.txt"]`

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
