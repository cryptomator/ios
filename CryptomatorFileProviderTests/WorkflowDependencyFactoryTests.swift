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

		wait(for: foo.lock)

		let expectedReadTasksPaths = [CloudPath("/"),
		                              CloudPath("/a"),
		                              CloudPath("/a"),
		                              CloudPath("/")]
		XCTAssertEqual(expectedReadTasksPaths, readTasksCollectionMock.insertForReceivedInvocations.map { $0.path })

		let expectedWriteTasksPaths = [CloudPath("/a/b"), CloudPath("/a/b")]
		XCTAssertEqual(expectedWriteTasksPaths, writeTasksCollectionMock.insertForReceivedInvocations.map { $0.path })

		foo.unlock.fulfill(())
		wait(for: foo.unlock)
	}

	// MARK: Write / Write

	func testWriteTaskDependentsOnExistingWriteTask() throws {
		let firstWriteTask = factory.createDependencies(for: CloudPath("/a/b"), lockType: .write)
		let secondWriteTask = factory.createDependencies(for: CloudPath("/a"), lockType: .write)
		wait(for: firstWriteTask.lock)
		XCTAssertGetsNotExecuted(secondWriteTask.lock)
		firstWriteTask.unlock.fulfill(())

		wait(for: secondWriteTask.lock)
		XCTAssertGetsNotExecuted(secondWriteTask.unlock)
		secondWriteTask.unlock.fulfill(())
		wait(for: secondWriteTask.unlock)

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
		wait(for: firstReadTask.lock)
		wait(for: secondReadTask.lock)
		XCTAssertGetsNotExecuted(firstReadTask.unlock)
		XCTAssertGetsNotExecuted(secondReadTask.unlock)
		firstReadTask.unlock.fulfill(())
		XCTAssertGetsNotExecuted(secondReadTask.unlock)
		secondReadTask.unlock.fulfill(())

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
		wait(for: dependenciesForReadTask.lock)
		XCTAssertGetsNotExecuted(dependenciesForWriteTask.lock)
		XCTAssertGetsNotExecuted(dependenciesForReadTask.unlock)

		dependenciesForReadTask.unlock.fulfill(())
		wait(for: dependenciesForWriteTask.lock)
		XCTAssertGetsNotExecuted(dependenciesForWriteTask.unlock)
		dependenciesForWriteTask.unlock.fulfill(())
		wait(for: dependenciesForWriteTask.unlock)

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
		wait(for: dependenciesForWriteTask.lock)
		XCTAssertGetsNotExecuted(dependenciesForReadTask.lock)
		XCTAssertGetsNotExecuted(dependenciesForWriteTask.unlock)

		dependenciesForWriteTask.unlock.fulfill(())
		wait(for: dependenciesForReadTask.lock)
		XCTAssertGetsNotExecuted(dependenciesForReadTask.unlock)
		dependenciesForReadTask.unlock.fulfill(())
		wait(for: dependenciesForReadTask.unlock)

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
		wait(for: dependenciesForMoveTask.lock)
		XCTAssertGetsNotExecuted(dependenciesForMoveTask.unlock)
		dependenciesForMoveTask.unlock.fulfill(())
		wait(for: dependenciesForMoveTask.unlock)

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
		wait(for: dependenciesForReadTask.lock)
		XCTAssertGetsNotExecuted(dependenciesForWriteTask.lock)
		XCTAssertGetsNotExecuted(dependenciesForReadTask.unlock)

		// Simulate error for read task
		dependenciesForReadTask.unlock.reject(NSError(domain: "SimulatedError", code: -100))

		// Write task can now acquire the lock
		wait(for: dependenciesForWriteTask.lock)
	}
}
