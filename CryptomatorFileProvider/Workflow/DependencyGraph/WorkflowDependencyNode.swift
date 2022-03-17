//
//  WorkflowDependencyNode.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 17.03.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation
import Promises

/**
 Workflow Dependency Node

  A workflow dependency node always belongs to exactly one workflow, where a workflow has a workflow dependency node for each path component.
  These nodes are always connected to their parent node - the node that belongs to the parent path.

  There can be only one node per path within this parent child relationship, however there can be `n` different nodes per path (created by other workflows).
  */
class WorkflowDependencyNode {
	enum LockType {
		case read
		case write
	}

	/// The lock type of the node
	let lockType: LockType
	lazy var isUnlocked: Promise<Void> = unlocked.then {
		// no-op
	}

	/**
	 Will be fulfilled as soon as a lock of type `lockType` could be acquired for the path. This happens as soon as, if present, a lock of the parent node could be acquired and all path dependencies were unlocked.
	 */
	lazy var isLocked: Promise<Void> = locked.then {
		// no-op
	}

	private let unlocked = Promise<Void>.pending()
	private let locked = Promise<Void>.pending()
	let path: CloudPath
	let parent: WorkflowDependencyNode?

	/**
	 Initializes a new workflow dependency node.

	 - parameters:
	    - path: The path to which the workflow dependency node belongs
	    - lockType: The lock type of the workflow dependency node
	    - parentNode: The parent node on which the newly created node is directly dependent. This should be the node that belongs to the parent path. Set to `nil` if there is no parent node.
	    - pathDependencies: The (external) nodes on which the newly created node depends via its path. These should all have the same path as `path`.
	 */
	init(path: CloudPath, lockType: LockType, parentNode: WorkflowDependencyNode?, pathDependencies: [WorkflowDependencyNode]) {
		assert(pathDependencies.allSatisfy({ $0.path == path }))
		self.path = path
		self.lockType = lockType
		self.parent = parentNode
		all(pathDependencies.map { $0.isUnlocked }).always {
			self.acquireLock()
		}
	}

	/**
	 Informs the current node about its child.

	 A parent node has a dependency to its direct child through its `unlocked` promise as a parent nodes `unlocked` propagates the status of its child `unlocked` promise.
	 */
	func setChild(_ child: WorkflowDependencyNode) {
		assert(child.parent == self)
		child.isUnlocked
			.then(unlocked.fulfill)
			.catch(unlocked.reject)
	}

	func unlock() {
		unlock(error: nil)
	}

	func unlock(with error: Error) {
		unlock(error: error)
	}

	private func unlock(error: Error?) {
		locked.catch(unlocked.reject).then {
			if let error = error {
				self.unlocked.reject(error)
			} else {
				self.unlocked.fulfill(())
			}
		}
	}

	private func waitForParentLock() -> Promise<Void> {
		return parent?.isLocked ?? Promise(())
	}

	private func acquireLock() {
		waitForParentLock().then(locked.fulfill).catch(locked.reject)
	}
}

extension WorkflowDependencyNode: Hashable {
	public func hash(into hasher: inout Hasher) {
		hasher.combine(ObjectIdentifier(self))
	}

	static func == (lhs: WorkflowDependencyNode, rhs: WorkflowDependencyNode) -> Bool {
		return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
	}
}
