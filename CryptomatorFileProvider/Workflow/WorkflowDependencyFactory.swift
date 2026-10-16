//
//  WorkflowDependencyFactory.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 30.03.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import Foundation

/**
 Workflow Dependency Factory

 The workflow dependency factory holds a collection of currently running/pending tasks allowing it to create a dependency graph between such tasks. This prevents, for example, that a file is uploaded to path `/a/b` before the corresponding folder is created on path `/a`.

 In case of such dependent tasks, it is required to invoke this factory in the correct order.
 */
@MainActor
final class WorkflowDependencyFactory {
	private typealias Registry = [CloudPath: [ObjectIdentifier: OneShotSignal<Void>]]

	private var readers = Registry()
	private var writers = Registry()

	nonisolated init() {}

	/**
	 Creates dependencies for the passed paths with the passed lock type.

	 The workflow waits on every writer registered on the paths and their ancestors, and a writing workflow also on every reader registered on the paths. It registers itself on the paths with the passed lock type and as a reader on their ancestors.

	 - Parameter paths: The paths for which dependencies are to be created. These are the full paths that affect a workflow.
	 */
	func createDependencies(paths: [CloudPath], lockType: LockType) -> WorkflowDependency {
		let registrations = createRegistrations(paths: paths, lockType: lockType)
		var predecessors = [ObjectIdentifier: OneShotSignal<Void>]()
		for registration in registrations {
			predecessors.merge(writers[registration.path] ?? [:]) { current, _ in current }
			if registration.lockType == .write {
				predecessors.merge(readers[registration.path] ?? [:]) { current, _ in current }
			}
		}
		let completion = OneShotSignal<Void>()
		for registration in registrations {
			updateRegistry(for: registration.lockType) { $0[registration.path, default: [:]][ObjectIdentifier(completion)] = completion }
		}
		return WorkflowDependency(predecessors: Array(predecessors.values), completion: completion, registrations: registrations, factory: self)
	}

	func createDependencies(for path: CloudPath, lockType: LockType) -> WorkflowDependency {
		return createDependencies(paths: [path], lockType: lockType)
	}

	fileprivate func unregister(_ completion: OneShotSignal<Void>, registrations: [LockRegistration]) {
		for registration in registrations {
			updateRegistry(for: registration.lockType) { $0[registration.path]?[ObjectIdentifier(completion)] = nil }
		}
	}

	private func createRegistrations(paths: [CloudPath], lockType: LockType) -> [LockRegistration] {
		var registrations = [LockRegistration]()
		for path in paths {
			var registration: LockRegistration? = LockRegistration(path: path, lockType: lockType)
			while let current = registration {
				if !registrations.contains(current) {
					registrations.append(current)
				}
				registration = current.path.getParent().map { LockRegistration(path: $0, lockType: .read) }
			}
		}
		return registrations
	}

	private func updateRegistry(for lockType: LockType, _ update: (inout Registry) -> Void) {
		switch lockType {
		case .read:
			update(&readers)
		case .write:
			update(&writers)
		}
	}
}

enum LockType {
	case read
	case write
}

struct LockRegistration: Equatable {
	let path: CloudPath
	let lockType: LockType
}

@MainActor
struct WorkflowDependency {
	private let predecessors: [OneShotSignal<Void>]
	private let completion: OneShotSignal<Void>
	let registrations: [LockRegistration]
	private let factory: WorkflowDependencyFactory

	fileprivate init(predecessors: [OneShotSignal<Void>], completion: OneShotSignal<Void>, registrations: [LockRegistration], factory: WorkflowDependencyFactory) {
		self.predecessors = predecessors
		self.completion = completion
		self.registrations = registrations
		self.factory = factory
	}

	func awaitPreconditions() async throws {
		for predecessor in predecessors {
			_ = try? await predecessor.value
		}
		try Task.checkCancellation()
		for registration in registrations {
			DDLogInfo("acquired lock for path: \(registration.path) - type: \(registration.lockType)")
		}
	}

	func notifyDependents() {
		factory.unregister(completion, registrations: registrations)
		for registration in registrations {
			DDLogInfo("released lock for path: \(registration.path) - type: \(registration.lockType)")
		}
		completion.fulfill(())
	}
}

extension CloudPath: @retroactive Hashable {
	public func hash(into hasher: inout Hasher) {
		hasher.combine(path)
	}
}
