//
//  WorkflowDependencyGraphTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 18.03.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Promises
import XCTest
@testable import CryptomatorFileProvider

class WorkflowDependencyGraphTests: XCTestCase {
	var graph: WorkflowDependencyGraph!
	let defaultPath = CloudPath("/a/b")

	override func setUpWithError() throws {
		graph = WorkflowDependencyGraph()
	}

	func testCreateSubgraphForWritingTask() throws {
		let path = CloudPath("/a/b")
		let task = createWritingTask(for: path)
		let node = graph.createDependencySubgraphForWritingTask(task)
		let parent = try XCTUnwrap(node.parent)
		assertNodeStoredInGraph(parent, expectedPath: CloudPath("/a"))
		let root = try XCTUnwrap(parent.parent)
		assertNodeStoredInGraph(root, expectedPath: CloudPath("/"))

		testBehaviorOfNodeWithoutDependencies(node)
	}

	func testCreateSubgraphForReadingTask() throws {
		let path = CloudPath("/a/b")
		let task = createReadingTask(for: path)
		let node = graph.createDependencySubgraphForReadingTask(task)
		let parent = try XCTUnwrap(node.parent)
		assertNodeStoredInGraph(parent, expectedPath: CloudPath("/a"))
		let root = try XCTUnwrap(parent.parent)
		assertNodeStoredInGraph(root, expectedPath: CloudPath("/"))

		testBehaviorOfNodeWithoutDependencies(node)
	}

	private func testBehaviorOfNodeWithoutDependencies(_ node: WorkflowDependencyNode) {
		assertAcquiredAllLocks(node: node)
		assertUnlockedNotFulfilled(node: node)
		node.unlock()
		assertUnlockedFulfilled(node: node)
	}

	// MARK: Write / Write

	func testCreateSubGraphForDeletionTaskExistingTask() throws {
		let parentPath = CloudPath("/a")
		let parentTask = createWritingTask(for: parentPath)
		let parentTaskNode = graph.createDependencySubgraphForWritingTask(parentTask)

		let path = CloudPath("/a/b")
		let task = createWritingTask(for: path)
		let node = graph.createDependencySubgraphForWritingTask(task)

		XCTAssertNotNil(graph["/"])
		XCTAssertEqual(path, node.path)

		let parent = try XCTUnwrap(node.parent)
		XCTAssertEqual(CloudPath("/a"), parent.path)

		let root = try XCTUnwrap(parent.parent)
		XCTAssertEqual(CloudPath("/"), root.path)
		XCTAssertNil(root.parent)

		XCTAssertGetsNotExecuted([node.isLocked, parent.isLocked, root.isLocked])

		parentTaskNode.unlock()
		wait(for: [root.isLocked, parent.isLocked, node.isLocked], timeout: 1.0, enforceOrder: true)
	}

	// MARK: Read / Read

	func testReadWorkflowsAreIndependent() throws {
		let parentPath = CloudPath("/a")
		let parentTask = createReadingTask(for: parentPath)
		let parentTaskNode = graph.createDependencySubgraphForReadingTask(parentTask)

		let path = CloudPath("/a/b")
		let task = createReadingTask(for: path)
		let node = graph.createDependencySubgraphForReadingTask(task)

		assertUnlockedNotFulfilled(node: parentTaskNode)
		assertUnlockedNotFulfilled(node: node)

		assertAcquiredAllLocks(node: parentTaskNode)
		assertAcquiredAllLocks(node: node)

		XCTAssertEqual([CloudPath("/")], getAllParentNodes(for: parentTaskNode).map { $0.path })
		XCTAssertEqual([CloudPath("/a"), CloudPath("/")], getAllParentNodes(for: node).map { $0.path })
	}

	// MARK: Read / Write

	func testWriteWorkflowIsDependentOnExistingReadWorkflow() throws {
		let path = CloudPath("/a/b")
		let readingTask = createReadingTask(for: path)
		let readingTaskNode = graph.createDependencySubgraphForReadingTask(readingTask)

		let writingTask = createWritingTask(for: path)
		let writingTaskNode = graph.createDependencySubgraphForWritingTask(writingTask)

		assertUnlockedNotFulfilled(node: readingTaskNode)
		assertUnlockedNotFulfilled(node: writingTaskNode)

		assertAcquiredAllLocks(node: readingTaskNode)
		let writingLock = writingTaskNode.isLocked
		let parentNodes = getAllParentNodes(for: writingTaskNode)
		XCTAssertEqual([CloudPath("/a"), CloudPath("/")], parentNodes.map { $0.path })
		XCTAssertGetsNotExecuted(writingLock)
		wait(for: parentNodes.map { $0.isLocked }.reversed(), timeout: 1.0, enforceOrder: true)

		// reading task is done
		readingTaskNode.unlock()

		wait(for: writingLock)
		assertUnlockedNotFulfilled(node: writingTaskNode)
	}

	// MARK: Write / Read

	func testReadWorkflowIsDependentOnExistingWriteWorkflow() throws {
		let path = CloudPath("/a/b")

		let writingTask = createWritingTask(for: path)
		let writingTaskNode = graph.createDependencySubgraphForWritingTask(writingTask)

		let readingTask = createReadingTask(for: path)
		let readingTaskNode = graph.createDependencySubgraphForReadingTask(readingTask)

		assertUnlockedNotFulfilled(node: readingTaskNode)
		assertUnlockedNotFulfilled(node: writingTaskNode)

		assertAcquiredAllLocks(node: writingTaskNode)
		let readingLock = readingTaskNode.isLocked
		XCTAssertGetsNotExecuted(readingLock)
		assertAcquiredParentLocks(node: readingTaskNode)

		// writing task is done
		writingTaskNode.unlock()

		wait(for: readingLock)
		assertUnlockedNotFulfilled(node: readingTaskNode)
	}

	// MARK: Move Task

	func testDependencyGraphForRenameTask() throws {
		let sourceCloudPath = CloudPath("/a/b")
		let targetCloudPath = CloudPath("/a/c")
		let moveTaskRecord = ReparentTaskRecord(correspondingItem: 3, sourceCloudPath: sourceCloudPath, targetCloudPath: targetCloudPath, oldParentID: 2, newParentID: 2)
		let renameTask = ReparentTask(taskRecord: moveTaskRecord, itemMetadata: createItemMetadata(for: sourceCloudPath))

		let moveTaskNodes = graph.createDependencySubgraph(for: renameTask)
		XCTAssertEqual(2, moveTaskNodes.count)
		let sourceWritingTaskNode = moveTaskNodes[0]
		let targetWritingTaskNode = moveTaskNodes[1]

		assertNodeStoredInGraph(sourceWritingTaskNode, expectedPath: sourceCloudPath)
		let sourceParentNode = try XCTUnwrap(sourceWritingTaskNode.parent, "Source parent node is missing")
		assertNodeStoredInGraph(sourceParentNode, expectedPath: CloudPath("/a"))
		let sourceRootNode = try XCTUnwrap(sourceParentNode.parent, "Source root node is missing")
		assertNodeStoredInGraph(sourceRootNode, expectedPath: CloudPath("/"))
		XCTAssertNil(sourceRootNode.parent, "The source root node is not expected to have a parent")
		testBehaviorOfNodeWithoutDependencies(sourceWritingTaskNode)

		assertNodeStoredInGraph(targetWritingTaskNode, expectedPath: targetCloudPath)
		let targetParentNode = try XCTUnwrap(targetWritingTaskNode.parent, "Target parent node is missing")
		assertNodeStoredInGraph(targetParentNode, expectedPath: CloudPath("/a"))
		let targetRootNode = try XCTUnwrap(targetParentNode.parent, "Target root node is missing")
		assertNodeStoredInGraph(targetRootNode, expectedPath: CloudPath("/"))
		XCTAssertNil(targetRootNode.parent, "The target root node is not expected to have a parent")
		testBehaviorOfNodeWithoutDependencies(targetWritingTaskNode)

		XCTAssertNotEqual(sourceRootNode, targetRootNode)
		XCTAssertNotEqual(sourceParentNode, targetParentNode)
	}

	// MARK: Dependent Task Errors do not propagate

	func testDependentTaskErrorsDoNotPropagate() {
		let path = CloudPath("/a/b")

		let writingTask = createWritingTask(for: path)
		let writingTaskNode = graph.createDependencySubgraphForWritingTask(writingTask)

		let readingTask = createReadingTask(for: path)
		let readingTaskNode = graph.createDependencySubgraphForReadingTask(readingTask)

		assertUnlockedNotFulfilled(node: readingTaskNode)
		assertUnlockedNotFulfilled(node: writingTaskNode)

		assertAcquiredAllLocks(node: writingTaskNode)
		let readingLock = readingTaskNode.isLocked
		XCTAssertGetsNotExecuted(readingLock)
		assertAcquiredParentLocks(node: readingTaskNode)
		// writing task is done
		writingTaskNode.unlock(with: NSError(domain: "Test", code: -100))

		wait(for: readingLock)
		assertUnlockedNotFulfilled(node: readingTaskNode)
	}

	private func assertUnlockedNotFulfilled(node: WorkflowDependencyNode) {
		XCTAssertGetsNotExecuted(getAllUnlockedPromises(for: node))
	}

	private func assertUnlockedFulfilled(node: WorkflowDependencyNode) {
		wait(for: getAllUnlockedPromises(for: node), timeout: 1.0, enforceOrder: true)
	}

	private func assertAcquiredAllLocks(node: WorkflowDependencyNode) {
		wait(for: getAllLockedPromises(for: node), timeout: 1.0, enforceOrder: true)
	}

	private func getAllParentNodes(for node: WorkflowDependencyNode) -> [WorkflowDependencyNode] {
		var parentNodes = [WorkflowDependencyNode]()
		var parentNode = node.parent

		while let currentParentNode = parentNode {
			parentNodes.append(currentParentNode)
			parentNode = currentParentNode.parent
		}
		return parentNodes
	}

	private func getAllUnlockedPromises(for node: WorkflowDependencyNode) -> [Promise<Void>] {
		var promises = [node.isUnlocked]
		var parentNode = node.parent

		while let currentParentNode = parentNode {
			promises.append(currentParentNode.isUnlocked)
			parentNode = currentParentNode.parent
		}
		return promises
	}

	private func getAllLockedPromises(for node: WorkflowDependencyNode) -> [Promise<Void>] {
		var promises = [node.isLocked]
		var parentNode = node.parent

		while let currentParentNode = parentNode {
			promises.append(currentParentNode.isLocked)
			parentNode = currentParentNode.parent
		}
		return promises.reversed()
	}

	private func createWritingTask(for cloudPath: CloudPath) -> CloudTask {
		let taskRecord = DeletionTaskRecord(correspondingItem: 2, cloudPath: cloudPath, parentID: 1, itemType: .folder)
		let task = DeletionTask(taskRecord: taskRecord, itemMetadata: .init(name: cloudPath.lastPathComponent, type: .folder, size: nil, parentID: 1, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false))
		return task
	}

	private func createReadingTask(for cloudPath: CloudPath) -> CloudTask {
		let itemMetadata = createItemMetadata(for: cloudPath)
		let taskRecord = ItemEnumerationTaskRecord(correspondingItem: itemMetadata.id!, pageToken: nil)
		let task = ItemEnumerationTask(taskRecord: taskRecord, itemMetadata: itemMetadata)
		return task
	}

	private func createItemMetadata(for cloudPath: CloudPath) -> ItemMetadata {
		return .init(id: 2, name: cloudPath.lastPathComponent, type: .file, size: nil, parentID: 1, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)
	}

	private func assertNodeStoredInGraph(_ node: WorkflowDependencyNode, expectedPath: CloudPath) {
		XCTAssertEqual(expectedPath, node.path)
		XCTAssertNotNil(graph[expectedPath.path])
		XCTAssert(graph[expectedPath.path]?.contains(node) ?? false)
	}

	private func assertAcquiredParentLocks(node: WorkflowDependencyNode, expectedParentPaths: [CloudPath] = [CloudPath("/a"), CloudPath("/")]) {
		let parentNodes = getAllParentNodes(for: node)
		XCTAssertEqual(expectedParentPaths, parentNodes.map { $0.path })
		wait(for: parentNodes.map { $0.isLocked }.reversed(), timeout: 1.0, enforceOrder: true)
	}
}
