//
//  WorkflowDependencyTasksCollectionMock.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 30.03.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation
import Promises
@testable import CryptomatorFileProvider

final class WorkflowDependencyTaskCollectionMock: WorkflowDependencyTaskCollectionType {
	private let collection = WorkflowDependencyTaskCollection()

	// MARK: - getTasks

	var getTasksForCallsCount = 0
	var getTasksForCalled: Bool {
		getTasksForCallsCount > 0
	}

	var getTasksForReceivedPath: CloudPath?
	var getTasksForReceivedInvocations: [CloudPath] = []
	var getTasksForReturnValue: Set<Promise<Void>>!
	lazy var getTasksForClosure: ((CloudPath) -> Set<Promise<Void>>)? = { [weak self] path in
		self?.collection.getTasks(for: path) ?? []
	}

	func getTasks(for path: CloudPath) -> Set<Promise<Void>> {
		getTasksForCallsCount += 1
		getTasksForReceivedPath = path
		getTasksForReceivedInvocations.append(path)
		return getTasksForClosure.map({ $0(path) }) ?? getTasksForReturnValue
	}

	// MARK: - insert

	var insertForCallsCount = 0
	var insertForCalled: Bool {
		insertForCallsCount > 0
	}

	var insertForReceivedArguments: (task: Promise<Void>, path: CloudPath)?
	var insertForReceivedInvocations: [(task: Promise<Void>, path: CloudPath)] = []
	lazy var insertForClosure: ((Promise<Void>, CloudPath) -> Void)? = { [weak self] task, path in
		self?.collection.insert(task, for: path)
	}

	func insert(_ task: Promise<Void>, for path: CloudPath) {
		insertForCallsCount += 1
		insertForReceivedArguments = (task: task, path: path)
		insertForReceivedInvocations.append((task: task, path: path))
		insertForClosure?(task, path)
	}

	// MARK: - remove

	var removeForCallsCount = 0
	var removeForCalled: Bool {
		removeForCallsCount > 0
	}

	var removeForReceivedArguments: (task: Promise<Void>, path: CloudPath)?
	var removeForReceivedInvocations: [(task: Promise<Void>, path: CloudPath)] = []
	lazy var removeForClosure: ((Promise<Void>, CloudPath) -> Void)? = { [weak self] task, path in
		self?.collection.remove(task, for: path)
	}

	func remove(_ task: Promise<Void>, for path: CloudPath) {
		removeForCallsCount += 1
		removeForReceivedArguments = (task: task, path: path)
		removeForReceivedInvocations.append((task: task, path: path))
		removeForClosure?(task, path)
	}
}
