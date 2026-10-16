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

@MainActor
class WorkflowDependencyFactoryTests: XCTestCase {
	var factory: WorkflowDependencyFactory!

	override func setUp() async throws {
		try await super.setUp()
		factory = WorkflowDependencyFactory()
	}

	func testSingleDependency() async throws {
		let foo = factory.createDependencies(for: CloudPath("/a/b"), lockType: .write)

		try await foo.awaitPreconditions()

		XCTAssertEqual([LockRegistration("/a/b", .write), LockRegistration("/a", .read), LockRegistration("/", .read)], foo.registrations)

		foo.notifyDependents()

		// once notified, the workflow no longer blocks a new writer on its path
		let bar = factory.createDependencies(for: CloudPath("/a/b"), lockType: .write)
		try await bar.awaitPreconditions()
	}

	// MARK: Write / Write

	func testWriteTaskDependentsOnExistingWriteTask() async throws {
		let firstWriteTask = factory.createDependencies(for: CloudPath("/a/b"), lockType: .write)
		let secondWriteTask = factory.createDependencies(for: CloudPath("/a"), lockType: .write)
		// check if first tasks starts immediately (but isn't completed yet, blocking the second task)
		try await firstWriteTask.awaitPreconditions()
		await assertStaysBlocked { try await secondWriteTask.awaitPreconditions() }

		// when the first task completes, check if the dependent second task starts
		firstWriteTask.notifyDependents()
		try await secondWriteTask.awaitPreconditions()
		secondWriteTask.notifyDependents()

		let expectedRegistrations = [LockRegistration("/a/b", .write),
		                             LockRegistration("/a", .read),
		                             LockRegistration("/", .read),
		                             LockRegistration("/a", .write),
		                             LockRegistration("/", .read)]
		XCTAssertEqual(expectedRegistrations, firstWriteTask.registrations + secondWriteTask.registrations)
	}

	// MARK: Read / Read

	func testParallelReadTasks() async throws {
		let firstReadTask = factory.createDependencies(for: CloudPath("/a/b"), lockType: .read)
		let secondReadTask = factory.createDependencies(for: CloudPath("/a"), lockType: .read)
		let writeTask = factory.createDependencies(for: CloudPath("/a"), lockType: .write)
		// check if both read tasks start immediately (but aren't completed yet, blocking the write task)
		try await firstReadTask.awaitPreconditions()
		try await secondReadTask.awaitPreconditions()
		await assertStaysBlocked { try await writeTask.awaitPreconditions() }

		// when the first read task completes, the second one still blocks the write task
		firstReadTask.notifyDependents()
		await assertStaysBlocked { try await writeTask.awaitPreconditions() }

		// when the second read task completes, the write task starts
		secondReadTask.notifyDependents()
		try await writeTask.awaitPreconditions()

		let expectedRegistrations = [LockRegistration("/a/b", .read),
		                             LockRegistration("/a", .read),
		                             LockRegistration("/", .read),
		                             LockRegistration("/a", .read),
		                             LockRegistration("/", .read),
		                             LockRegistration("/a", .write),
		                             LockRegistration("/", .read)]
		XCTAssertEqual(expectedRegistrations, firstReadTask.registrations + secondReadTask.registrations + writeTask.registrations)
	}

	// MARK: Read / Write

	func testWriteTaskDependentOnExistingReadTask() async throws {
		let dependenciesForReadTask = factory.createDependencies(for: CloudPath("/a/b"), lockType: .read)
		let dependenciesForWriteTask = factory.createDependencies(for: CloudPath("/a"), lockType: .write)
		// check if read tasks starts immediately (but isn't completed yet, blocking the write task)
		try await dependenciesForReadTask.awaitPreconditions()
		await assertStaysBlocked { try await dependenciesForWriteTask.awaitPreconditions() }

		// when the read task completes, check if the dependent write task starts
		dependenciesForReadTask.notifyDependents()
		try await dependenciesForWriteTask.awaitPreconditions()
		dependenciesForWriteTask.notifyDependents()

		let expectedRegistrations = [LockRegistration("/a/b", .read),
		                             LockRegistration("/a", .read),
		                             LockRegistration("/", .read),
		                             LockRegistration("/a", .write),
		                             LockRegistration("/", .read)]
		XCTAssertEqual(expectedRegistrations, dependenciesForReadTask.registrations + dependenciesForWriteTask.registrations)
	}

	// MARK: Write / Read

	func testReadTaskDependentOnExistingWriteTask() async throws {
		let dependenciesForWriteTask = factory.createDependencies(for: CloudPath("/a"), lockType: .write)
		let dependenciesForReadTask = factory.createDependencies(for: CloudPath("/a/b"), lockType: .read)
		// check if write tasks starts immediately (but isn't completed yet, blocking the read task)
		try await dependenciesForWriteTask.awaitPreconditions()
		await assertStaysBlocked { try await dependenciesForReadTask.awaitPreconditions() }

		// when the write task completes, check if the dependent read task starts
		dependenciesForWriteTask.notifyDependents()
		try await dependenciesForReadTask.awaitPreconditions()
		dependenciesForReadTask.notifyDependents()

		let expectedRegistrations = [LockRegistration("/a", .write),
		                             LockRegistration("/", .read),
		                             LockRegistration("/a/b", .read),
		                             LockRegistration("/a", .read),
		                             LockRegistration("/", .read)]
		XCTAssertEqual(expectedRegistrations, dependenciesForWriteTask.registrations + dependenciesForReadTask.registrations)
	}

	// MARK: Move Task

	func testDependencyForMoveTask() async throws {
		let sourceCloudPath = CloudPath("/a/b")
		let targetCloudPath = CloudPath("/a/c")

		let dependenciesForMoveTask = factory.createDependencies(paths: [sourceCloudPath, targetCloudPath], lockType: .write)
		// check if move task starts immediately
		try await dependenciesForMoveTask.awaitPreconditions()
		dependenciesForMoveTask.notifyDependents()

		// the ancestors shared by source and target register once
		let expectedRegistrations = [LockRegistration("/a/b", .write),
		                             LockRegistration("/a", .read),
		                             LockRegistration("/", .read),
		                             LockRegistration("/a/c", .write)]
		XCTAssertEqual(expectedRegistrations, dependenciesForMoveTask.registrations)
	}

	func testWriteTaskDependentOnExistingMoveTask() async throws {
		let dependenciesForMoveTask = factory.createDependencies(paths: [CloudPath("/a/b"), CloudPath("/c/b")], lockType: .write)
		let dependenciesForWriteTask = factory.createDependencies(for: CloudPath("/c/b"), lockType: .write)
		// check if move task starts immediately (but isn't completed yet, blocking the write task on the move target)
		try await dependenciesForMoveTask.awaitPreconditions()
		await assertStaysBlocked { try await dependenciesForWriteTask.awaitPreconditions() }

		// when the move task completes, check if the dependent write task starts
		dependenciesForMoveTask.notifyDependents()
		try await dependenciesForWriteTask.awaitPreconditions()
		dependenciesForWriteTask.notifyDependents()
	}

	func testWriteTaskOnDescendantDependentOnExistingMoveTask() async throws {
		let dependenciesForMoveTask = factory.createDependencies(paths: [CloudPath("/a"), CloudPath("/c")], lockType: .write)
		let dependenciesForWriteTask = factory.createDependencies(for: CloudPath("/c/d"), lockType: .write)
		// check if move task starts immediately (but isn't completed yet, blocking the write task below the move target)
		try await dependenciesForMoveTask.awaitPreconditions()
		await assertStaysBlocked { try await dependenciesForWriteTask.awaitPreconditions() }

		// when the move task completes, check if the dependent write task starts
		dependenciesForMoveTask.notifyDependents()
		try await dependenciesForWriteTask.awaitPreconditions()
		dependenciesForWriteTask.notifyDependents()
	}
}

private extension LockRegistration {
	init(_ path: String, _ lockType: LockType) {
		self.init(path: CloudPath(path), lockType: lockType)
	}
}
