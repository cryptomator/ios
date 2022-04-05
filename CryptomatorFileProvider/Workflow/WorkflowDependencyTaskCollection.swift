//
//  WorkflowDependencyTaskCollection.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 31.03.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation
import Promises

protocol WorkflowDependencyTaskCollectionType {
	func getTasks(for path: CloudPath) -> Set<Promise<Void>>
	func insert(_ task: Promise<Void>, for path: CloudPath)
	func remove(_ task: Promise<Void>, for path: CloudPath)
}

extension WorkflowDependencyTaskCollectionType {
	subscript(key: CloudPath) -> Set<Promise<Void>> {
		return getTasks(for: key)
	}
}

/// Thread-safe implementation of a WorkflowDependencyTaskCollection.
class WorkflowDependencyTaskCollection: WorkflowDependencyTaskCollectionType {
	private let queue = DispatchQueue(label: "WorkflowDependencyTaskCollection", attributes: .concurrent)
	private lazy var tasks = [CloudPath: Set<Promise<Void>>]()

	func getTasks(for path: CloudPath) -> Set<Promise<Void>> {
		queue.sync {
			tasks[path] ?? []
		}
	}

	func insert(_ task: Promise<Void>, for path: CloudPath) {
		queue.async(flags: .barrier) { [self] in
			tasks[path] = tasks[path] ?? []
			tasks[path]?.insert(task)
		}
	}

	func remove(_ task: Promise<Void>, for path: CloudPath) {
		queue.async(flags: .barrier) { [self] in
			tasks[path]?.remove(task)
		}
	}
}

extension Promise: Hashable {
	public static func == (lhs: Promise<Value>, rhs: Promise<Value>) -> Bool {
		return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
	}

	public func hash(into hasher: inout Hasher) {
		hasher.combine(ObjectIdentifier(self))
	}
}

extension CloudPath: Hashable {
	public func hash(into hasher: inout Hasher) {
		hasher.combine(path)
	}
}
