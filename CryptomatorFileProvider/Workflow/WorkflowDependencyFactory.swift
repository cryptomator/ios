//
//  WorkflowDependencyFactory.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 30.03.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import CryptomatorCloudAccessCore
import Foundation
import Promises

/**
 Workflow Dependency Factory

 The workflow dependency factory holds a collection of currently running/pending tasks allowing it to create a dependency graph between such tasks. This prevents, for example, that a file is uploaded to path `/a/b` before the corresponding folder is created on path `/a`.

 In case of such dependent tasks, it is required to invoke this factory in the correct order.
 */
class WorkflowDependencyFactory {
	private let readTasks: WorkflowDependencyTaskCollectionType
	private let writeTasks: WorkflowDependencyTaskCollectionType

	init(readTasks: WorkflowDependencyTaskCollectionType, writeTasks: WorkflowDependencyTaskCollectionType) {
		self.readTasks = readTasks
		self.writeTasks = writeTasks
	}

	convenience init() {
		self.init(readTasks: WorkflowDependencyTaskCollection(), writeTasks: WorkflowDependencyTaskCollection())
	}

	/**
	 Creates dependencies for the passed paths with the passed lock type.

	 - Parameter paths: The paths for which dependencies are to be created. These are the full paths that affect a workflow.
	 - Parameter lockType: The lock type used to construct the leaf nodes (the nodes for the respective full path).
	 */
	public func createDependencies(paths: [CloudPath], lockType: LockType) -> WorkflowDependency {
		let unlock = Promise<Void>.pending()
		var locks = [Promise<Void>]()
		for path in paths {
			let lock = createLock(path: path, type: lockType)
			locks.append(lock)
			createUnlock(path: path, type: lockType, basedOn: unlock)
		}
		let lock: Promise<Void> = all(locks).then { _ -> Void in
			// no-op
		}
		return WorkflowDependency(lock: lock, unlock: unlock)
	}

	/**
	 Creates dependencies for the passed path with the passed lock type.

	 - Parameter path: The path for which dependencies are to be created. These is the full path that affect a workflow.
	 - Parameter lockType: The lock type used to construct the leaf nodes (the nodes for the respective full path).
	 */
	public func createDependencies(for path: CloudPath, lockType: LockType) -> WorkflowDependency {
		return createDependencies(paths: [path], lockType: lockType)
	}

	/**
	 Creates chain of "lock" promises for the given path.

	 For the passed path there is a top-down dependency between the promises, i.e. a promise for the child path depends on the promise for the parent path.
	 */
	private func createLock(path: CloudPath, type: LockType) -> Promise<Void> {
		var dependencies = [Promise<Void>]()
		if let parentPath = path.getParent() {
			let parentLock = createLock(path: parentPath, type: .read)
			dependencies.append(parentLock)
		}
		// All tasks wait for other write tasks on the same path
		let writeTasksForPath = writeTasks[path]
		let allWriteTasksFinished = all(ignoringResult: writeTasksForPath)
		dependencies.append(allWriteTasksFinished)

		// Only write tasks wait for other read tasks on the same path
		if type == .write {
			let readTasksForPath = readTasks[path]
			let allReadTasksFinished = all(ignoringResult: readTasksForPath)
			dependencies.append(allReadTasksFinished)
		}
		let lock: Promise<Void> = all(dependencies).then { _ -> Void in
			// no-op
			DDLogInfo("acquired lock for path: \(path) - type: \(type)")
		}
		addToCollection(lock, path: path, type: type)
		lock.always {
			self.removeFromCollection(lock, path: path, type: type)
		}
		return lock
	}

	/**
	 Creates chain of "unlock" promises for the given path.

	 For the passed path there is a bottom-up dependency between the promises, i.e. a promise for the parent path depends on the promise for the child path.
	 */
	private func createUnlock(path: CloudPath, type: LockType, basedOn child: Promise<Void>) {
		let unlock = child.then {
			// no-op
			DDLogInfo("released lock for path: \(path) - type: \(type)")
		}
		addToCollection(unlock, path: path, type: type)
		unlock.always {
			self.removeFromCollection(unlock, path: path, type: type)
		}
		if let parentPath = path.getParent() {
			createUnlock(path: parentPath, type: .read, basedOn: unlock)
		}
	}

	private func addToCollection(_ task: Promise<Void>, path: CloudPath, type: LockType) {
		let collection: WorkflowDependencyTaskCollectionType
		switch type {
		case .read:
			collection = readTasks
		case .write:
			collection = writeTasks
		}
		collection.insert(task, for: path)
	}

	private func removeFromCollection(_ task: Promise<Void>, path: CloudPath, type: LockType) {
		let collection: WorkflowDependencyTaskCollectionType
		switch type {
		case .read:
			collection = readTasks
		case .write:
			collection = writeTasks
		}
		collection.remove(task, for: path)
	}
}

enum LockType {
	case read
	case write
}

struct WorkflowDependency {
	// visible for testing
	var workflowCompleted: Promise<Void> {
		return unlock
	}

	private let lock: Promise<Void>
	private let unlock: Promise<Void>

	init(lock: Promise<Void>, unlock: Promise<Void>) {
		self.lock = lock
		self.unlock = unlock
	}

	func awaitPreconditions() -> Promise<Void> {
		return lock.then {
			// no-op
		}
	}

	func notifyDependents(with error: Error?) {
		if let error = error {
			unlock.reject(error)
		} else {
			unlock.fulfill(())
		}
	}
}
