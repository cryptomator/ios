//
//  WorkflowDependencyGraph.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 23.03.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation

class WorkflowDependencyGraph {
	/**
	 Store for the workflow dependency nodes.

	 The key is a path and the value is a `NSHashTable` of `WorkflowDependencyNodes` belonging to that path.
	 */
	private(set) var store = [String: NSHashTable<WorkflowDependencyNode>]()

	subscript(key: String) -> NSHashTable<WorkflowDependencyNode>? {
		store[key]
	}

	/**
	 Adds nodes to the graph for a writing task at a given path and returns the leaf of the resulting dependency subgraph.

	 A dependency subgraph for a writing task consists of the following nodes:

	 For each path component a read node is created, which are top down dependent on each other to acquire a lock and will be reverse unlocked.
	 Additionally, each read node is dependent on existing write nodes for the same path component, i.e. a read node for path component `/a` is dependent on existing write nodes for path component `/a` but not on existing write nodes for path component `/b`.

	 A write node is created only for the last path component - the full path. This node depends on the read nodes previously created in this function, as well as on all existing read nodes for the same path component as the write node.
	 The write node is thus the leaf of the subgraph and is therefore the node returned by this function.
	 */
	func createDependencySubgraphForWritingTask(_ task: CloudTask) -> WorkflowDependencyNode {
		return createDependencySubgraph(writingAt: task.cloudPath)
	}

	/**
	 Adds nodes to the graph for a reading task at a given path and returns the leaf of the resulting dependency subgraph.

	 A dependency subgraph for a reading task consists of the following nodes:

	 For each path component a read node is created, which are top down dependent on each other to acquire a lock and will be reverse unlocked.
	 Additionally, each read node is dependent on existing write nodes for the same path component, i.e. a read node for path component `/a` is dependent on existing write nodes for path component `/a` but not on existing write nodes for path component `/b`.

	 The node for the full path is the leaf of the subgraph and is therefore the node returned by this function.
	 */
	func createDependencySubgraphForReadingTask(_ task: CloudTask) -> WorkflowDependencyNode {
		return createDependencySubgraph(readingAt: task.cloudPath)
	}

	/**
	 Creates a dependency subgraph for a given reparent task.

	 A dependency subgraph for a reparent task consists of a graph for a writing task on the source cloud path and a graph for a writing task on the target cloud path.
	 */
	func createDependencySubgraph(for reparentTask: ReparentTask) -> [WorkflowDependencyNode] {
		let sourcePathSubgraph = createDependencySubgraph(writingAt: reparentTask.taskRecord.sourceCloudPath)
		let targetPathSubgraph = createDependencySubgraph(writingAt: reparentTask.taskRecord.targetCloudPath)
		return [sourcePathSubgraph, targetPathSubgraph]
	}

	private func createDependencyNode(for path: CloudPath, lockType: WorkflowDependencyNode.LockType, parentNode: WorkflowDependencyNode?) -> WorkflowDependencyNode {
		let pathDependencies = getPathDependencies(for: path, lockType: lockType)
		let node = WorkflowDependencyNode(path: path,
		                                  lockType: lockType,
		                                  parentNode: parentNode,
		                                  pathDependencies: pathDependencies)
		storeNode(node)
		parentNode?.setChild(node)
		return node
	}

	private func createDependencySubgraph(writingAt path: CloudPath) -> WorkflowDependencyNode {
		let lockPaths = path.getPartialCloudPaths().dropLast(1)
		var parentNode: WorkflowDependencyNode?

		for partialPath in lockPaths {
			let node = createDependencyNode(for: partialPath, lockType: .read, parentNode: parentNode)
			parentNode = node
		}
		let node = createDependencyNode(for: path, lockType: .write, parentNode: parentNode)
		return node
	}

	private func createDependencySubgraph(readingAt path: CloudPath) -> WorkflowDependencyNode {
		let lockPaths = path.getPartialCloudPaths().dropLast(1)
		var parentNode: WorkflowDependencyNode?

		for partialPath in lockPaths {
			let node = createDependencyNode(for: partialPath, lockType: .read, parentNode: parentNode)
			parentNode = node
		}
		let node = createDependencyNode(for: path, lockType: .read, parentNode: parentNode)
		return node
	}

	/**
	 Returns the "external" / horizontal dependencies for a given cloud path and lock type.

	 For a `LockType.read` all existing nodes with lock type `LockType.write`  for the given cloud path are returned.
	 For a `LockType.write` all existing nodes for the given cloud path are returned.
	 */
	private func getPathDependencies(for cloudPath: CloudPath, lockType: WorkflowDependencyNode.LockType) -> [WorkflowDependencyNode] {
		guard let currentLocks = store[cloudPath.path]?.allObjects else {
			return []
		}
		switch lockType {
		case .read:
			return currentLocks.filter { $0.lockType == .write }
		case .write:
			return currentLocks
		}
	}

	/**
	 Stores the node for its path.

	 If there have never been nodes for this path, a new `NSHashTable` is created with the `.weakMemory` option.
	 This ensures that nodes are not stored longer than necessary.
	 Therefore it must be ensured that active nodes are referenced as long as they are supposed to be active.
	 */
	private func storeNode(_ node: WorkflowDependencyNode) {
		let cloudPath = node.path
		if let array = store[cloudPath.path] {
			array.add(node)
		} else {
			let array = NSHashTable<WorkflowDependencyNode>(options: .weakMemory)
			array.add(node)
			store[cloudPath.path] = array
		}
	}
}
