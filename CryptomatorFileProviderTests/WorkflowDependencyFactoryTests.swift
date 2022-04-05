//
//  WorkflowDependencyFactoryTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 30.03.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import XCTest
@testable import CryptomatorFileProvider

class WorkflowDependencyFactoryTests: XCTestCase {
	var factory: WorkflowDependencyFactory!
	var readTasksCollectionMock: WorkflowDependencyTaskCollectionMock!
	var writeTasksCollectionMock: WorkflowDependencyTaskCollectionMock!

	override func setUpWithError() throws {
		readTasksCollectionMock = WorkflowDependencyTaskCollectionMock()
		writeTasksCollectionMock = WorkflowDependencyTaskCollectionMock()
		factory = WorkflowDependencyFactory(readTasks: readTasksCollectionMock,
		                                    writeTasks: writeTasksCollectionMock)
	}

	func testSingleDependency() throws {
		let foo = factory.createDependencies(for: CloudPath("/a/b"), lockType: .write)

		wait(for: foo.awaitPreconditions())

		let expectedReadTasksPaths = [CloudPath("/"),
		                              CloudPath("/a"),
		                              CloudPath("/a"),
		                              CloudPath("/")]
		XCTAssertEqual(expectedReadTasksPaths, readTasksCollectionMock.insertForReceivedInvocations.map { $0.path })

		let expectedWriteTasksPaths = [CloudPath("/a/b"), CloudPath("/a/b")]
		XCTAssertEqual(expectedWriteTasksPaths, writeTasksCollectionMock.insertForReceivedInvocations.map { $0.path })

		foo.notifyDependents(with: nil)
		wait(for: foo.workflowCompleted)
	}

	// MARK: Write / Write

	func testWriteTaskDependentsOnExistingWriteTask() throws {
		let firstWriteTask = factory.createDependencies(for: CloudPath("/a/b"), lockType: .write)
		let secondWriteTask = factory.createDependencies(for: CloudPath("/a"), lockType: .write)
		// check if first tasks starts immediately (but isn't completed yet, blocking the second task)
		wait(for: firstWriteTask.awaitPreconditions())
		XCTAssertGetsNotExecuted(secondWriteTask.awaitPreconditions())

		// when the first task completes, check if the dependent second task starts (but doesn't finish yet)
		firstWriteTask.workflowCompleted.fulfill(())

		wait(for: secondWriteTask.awaitPreconditions())
		XCTAssertGetsNotExecuted(secondWriteTask.workflowCompleted)

		// when the second task completes its completion promise is fulfilled
		secondWriteTask.workflowCompleted.fulfill(())
		wait(for: secondWriteTask.workflowCompleted)

		let expectedFirstWriteTaskReadLockPaths = [CloudPath("/"),
		                                           CloudPath("/a")]
		let expectedFirstWriteTaskReadUnlockPaths = expectedFirstWriteTaskReadLockPaths.reversed()
		let expectedSecondWriteTaskReadLockPaths = [CloudPath("/")]
		let expectedSecondWriteTaskReadUnlockPaths = expectedSecondWriteTaskReadLockPaths.reversed()
		var expectedReadTasksPaths = [CloudPath]()
		expectedReadTasksPaths.append(contentsOf: expectedFirstWriteTaskReadLockPaths)
		expectedReadTasksPaths.append(contentsOf: expectedFirstWriteTaskReadUnlockPaths)
		expectedReadTasksPaths.append(contentsOf: expectedSecondWriteTaskReadLockPaths)
		expectedReadTasksPaths.append(contentsOf: expectedSecondWriteTaskReadUnlockPaths)
		let actualReadTasksPaths = readTasksCollectionMock.insertForReceivedInvocations.map { $0.path }
		XCTAssertEqual(expectedReadTasksPaths, actualReadTasksPaths)

		let expectedWriteTasksPaths = [CloudPath("/a/b"),
		                               CloudPath("/a/b"),
		                               CloudPath("/a"),
		                               CloudPath("/a")]
		let actualWriteTasksPaths = writeTasksCollectionMock.insertForReceivedInvocations.map { $0.path }
		XCTAssertEqual(expectedWriteTasksPaths, actualWriteTasksPaths)
	}

	// MARK: Read / Read

	func testParallelReadTasks() throws {
		let firstReadTask = factory.createDependencies(for: CloudPath("/a/b"), lockType: .read)
		let secondReadTask = factory.createDependencies(for: CloudPath("/a"), lockType: .read)
		// check if both tasks start immediately (but aren't completed yet)
		wait(for: firstReadTask.awaitPreconditions())
		wait(for: secondReadTask.awaitPreconditions())
		XCTAssertGetsNotExecuted(firstReadTask.workflowCompleted)
		XCTAssertGetsNotExecuted(secondReadTask.workflowCompleted)

		// when the first task completes its completion promise is fulfilled but the second task isn't
		firstReadTask.workflowCompleted.fulfill(())
		wait(for: firstReadTask.workflowCompleted)
		XCTAssertGetsNotExecuted(secondReadTask.workflowCompleted)

		// when the second task completes its completion promise is fulfilled
		secondReadTask.workflowCompleted.fulfill(())
		wait(for: secondReadTask.workflowCompleted)

		let expectedFirstReadTaskLockPaths = [CloudPath("/"),
		                                      CloudPath("/a"),
		                                      CloudPath("/a/b")]
		let expectedFirstReadTaskUnlockPaths = expectedFirstReadTaskLockPaths.reversed()
		let expectedSecondReadTaskLockPaths = [CloudPath("/"),
		                                       CloudPath("/a")]
		let expectedSecondReadTaskUnlockPaths = expectedSecondReadTaskLockPaths.reversed()
		var expectedReadTasksPaths = [CloudPath]()
		expectedReadTasksPaths.append(contentsOf: expectedFirstReadTaskLockPaths)
		expectedReadTasksPaths.append(contentsOf: expectedFirstReadTaskUnlockPaths)
		expectedReadTasksPaths.append(contentsOf: expectedSecondReadTaskLockPaths)
		expectedReadTasksPaths.append(contentsOf: expectedSecondReadTaskUnlockPaths)
		let actualReadTasksPaths = readTasksCollectionMock.insertForReceivedInvocations.map { $0.path }
		XCTAssertEqual(expectedReadTasksPaths, actualReadTasksPaths)
	}

	// MARK: Read / Write

	func testWriteTaskDependentOnExistingReadTask() throws {
		let dependenciesForReadTask = factory.createDependencies(for: CloudPath("/a/b"), lockType: .read)
		let dependenciesForWriteTask = factory.createDependencies(for: CloudPath("/a"), lockType: .write)
		// check if read tasks starts immediately (but isn't completed yet, blocking the write task)
		wait(for: dependenciesForReadTask.awaitPreconditions())
		XCTAssertGetsNotExecuted(dependenciesForWriteTask.awaitPreconditions())
		XCTAssertGetsNotExecuted(dependenciesForReadTask.workflowCompleted)

		// when the read task completes, check if the dependent write task starts (but doesn't finish yet)
		dependenciesForReadTask.workflowCompleted.fulfill(())
		wait(for: dependenciesForWriteTask.awaitPreconditions())
		XCTAssertGetsNotExecuted(dependenciesForWriteTask.workflowCompleted)

		// when the write task completes its completion promise is fulfilled
		dependenciesForWriteTask.workflowCompleted.fulfill(())
		wait(for: dependenciesForWriteTask.workflowCompleted)

		let expectedReadTaskLockPaths = [CloudPath("/"),
		                                 CloudPath("/a"),
		                                 CloudPath("/a/b")]
		let expectedReadTaskUnlockPaths = expectedReadTaskLockPaths.reversed()
		let expectedWriteTaskReadLockPaths = [CloudPath("/")]
		let expectedWriteTaskReadUnlockPaths = expectedWriteTaskReadLockPaths.reversed()
		var expectedReadTasksPaths = [CloudPath]()
		expectedReadTasksPaths.append(contentsOf: expectedReadTaskLockPaths)
		expectedReadTasksPaths.append(contentsOf: expectedReadTaskUnlockPaths)
		expectedReadTasksPaths.append(contentsOf: expectedWriteTaskReadLockPaths)
		expectedReadTasksPaths.append(contentsOf: expectedWriteTaskReadUnlockPaths)
		let actualReadTasksPaths = readTasksCollectionMock.insertForReceivedInvocations.map { $0.path }
		XCTAssertEqual(expectedReadTasksPaths, actualReadTasksPaths)

		let expectedWriteTasksLockPath = CloudPath("/a")
		let expectedWriteTasksUnlockPath = expectedWriteTasksLockPath
		let expectedWriteTasksPaths = [expectedWriteTasksLockPath, expectedWriteTasksUnlockPath]
		let actualWriteTasksPaths = writeTasksCollectionMock.insertForReceivedInvocations.map { $0.path }
		XCTAssertEqual(expectedWriteTasksPaths, actualWriteTasksPaths)
	}

	// MARK: Write / Read

	func testReadTaskDependentOnExistingWriteTask() throws {
		let dependenciesForWriteTask = factory.createDependencies(for: CloudPath("/a"), lockType: .write)
		let dependenciesForReadTask = factory.createDependencies(for: CloudPath("/a/b"), lockType: .read)
		// check if write tasks starts immediately (but isn't completed yet, blocking the read task)
		wait(for: dependenciesForWriteTask.awaitPreconditions())
		XCTAssertGetsNotExecuted(dependenciesForReadTask.awaitPreconditions())
		XCTAssertGetsNotExecuted(dependenciesForWriteTask.workflowCompleted)

		// when the write task completes, check if the dependent read task starts (but doesn't finish yet)
		dependenciesForWriteTask.workflowCompleted.fulfill(())
		wait(for: dependenciesForReadTask.awaitPreconditions())
		XCTAssertGetsNotExecuted(dependenciesForReadTask.workflowCompleted)

		// when the read task completes its completion promise is fulfilled
		dependenciesForReadTask.workflowCompleted.fulfill(())
		wait(for: dependenciesForReadTask.workflowCompleted)

		let expectedWriteTaskReadLockPaths = [CloudPath("/")]
		let expectedWriteTaskReadUnlockPaths = expectedWriteTaskReadLockPaths.reversed()
		let expectedReadTaskLockPaths = [CloudPath("/"),
		                                 CloudPath("/a"),
		                                 CloudPath("/a/b")]
		let expectedReadTaskUnlockPaths = expectedReadTaskLockPaths.reversed()
		var expectedReadTasksPaths = [CloudPath]()
		expectedReadTasksPaths.append(contentsOf: expectedWriteTaskReadLockPaths)
		expectedReadTasksPaths.append(contentsOf: expectedWriteTaskReadUnlockPaths)
		expectedReadTasksPaths.append(contentsOf: expectedReadTaskLockPaths)
		expectedReadTasksPaths.append(contentsOf: expectedReadTaskUnlockPaths)
		let actualReadTasksPaths = readTasksCollectionMock.insertForReceivedInvocations.map { $0.path }
		XCTAssertEqual(expectedReadTasksPaths, actualReadTasksPaths)

		let expectedWriteTasksLockPath = CloudPath("/a")
		let expectedWriteTasksUnlockPath = expectedWriteTasksLockPath
		let expectedWriteTasksPaths = [expectedWriteTasksLockPath, expectedWriteTasksUnlockPath]
		let actualWriteTasksPaths = writeTasksCollectionMock.insertForReceivedInvocations.map { $0.path }
		XCTAssertEqual(expectedWriteTasksPaths, actualWriteTasksPaths)
	}

	// MARK: Move Task

	func testDependencyForMoveTask() throws {
		let sourceCloudPath = CloudPath("/a/b")
		let targetCloudPath = CloudPath("/a/c")

		let dependenciesForMoveTask = factory.createDependencies(paths: [sourceCloudPath, targetCloudPath], lockType: .write)
		// check if move task starts immediately (but doesn't complete yet)
		wait(for: dependenciesForMoveTask.awaitPreconditions())
		XCTAssertGetsNotExecuted(dependenciesForMoveTask.workflowCompleted)

		// when the move task completes its completion promise is fulfilled
		dependenciesForMoveTask.workflowCompleted.fulfill(())
		wait(for: dependenciesForMoveTask.workflowCompleted)

		let expectedSourceWriteTaskReadLockPaths = [CloudPath("/"),
		                                            CloudPath("/a")]
		let expectedSourceWriteTaskReadUnlockPaths = expectedSourceWriteTaskReadLockPaths.reversed()
		let expectedTargetWriteTaskReadLockPaths = [CloudPath("/"),
		                                            CloudPath("/a")]
		let expectedTargetWriteTaskReadUnlockPaths = expectedTargetWriteTaskReadLockPaths.reversed()
		var expectedReadTasksPaths = [CloudPath]()
		expectedReadTasksPaths.append(contentsOf: expectedSourceWriteTaskReadLockPaths)
		expectedReadTasksPaths.append(contentsOf: expectedSourceWriteTaskReadUnlockPaths)
		expectedReadTasksPaths.append(contentsOf: expectedTargetWriteTaskReadLockPaths)
		expectedReadTasksPaths.append(contentsOf: expectedTargetWriteTaskReadUnlockPaths)
		let actualReadTasksPaths = readTasksCollectionMock.insertForReceivedInvocations.map { $0.path }
		XCTAssertEqual(expectedReadTasksPaths, actualReadTasksPaths)

		let expectedSourceWriteTasksLockPath = CloudPath("/a/b")
		let expectedSourceWriteTasksUnlockPath = expectedSourceWriteTasksLockPath

		let expectedTargetWriteTasksLockPath = CloudPath("/a/c")
		let expectedTargetWriteTasksUnlockPath = expectedTargetWriteTasksLockPath

		let expectedWriteTasksPaths = [expectedSourceWriteTasksLockPath,
		                               expectedSourceWriteTasksUnlockPath,
		                               expectedTargetWriteTasksLockPath,
		                               expectedTargetWriteTasksUnlockPath]
		let actualWriteTasksPaths = writeTasksCollectionMock.insertForReceivedInvocations.map { $0.path }
		XCTAssertEqual(expectedWriteTasksPaths, actualWriteTasksPaths)
	}

	// MARK: Error propagation

	func testErrorDoesNotPropagateBetweenDependentWorkflows() {
		let dependenciesForReadTask = factory.createDependencies(for: CloudPath("/a/b"), lockType: .read)
		let dependenciesForWriteTask = factory.createDependencies(for: CloudPath("/a"), lockType: .write)
		// check if read task starts immediately (but doesn't complete yet, blocking the write task)
		wait(for: dependenciesForReadTask.awaitPreconditions())
		XCTAssertGetsNotExecuted(dependenciesForWriteTask.awaitPreconditions())
		XCTAssertGetsNotExecuted(dependenciesForReadTask.workflowCompleted)

		// Simulate error for read task
		dependenciesForReadTask.workflowCompleted.reject(NSError(domain: "SimulatedError", code: -100))

		// Write task can now acquire the lock
		wait(for: dependenciesForWriteTask.awaitPreconditions())
	}
}
