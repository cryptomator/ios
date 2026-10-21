//
//  WorkflowScheduler.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 28.05.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation

@MainActor
class WorkflowScheduler {
	nonisolated init() {}

	func schedule<T>(_ workflow: Workflow<T>) async throws -> T {
		return try await workflow.middleware.execute(task: workflow.task)
	}
}
