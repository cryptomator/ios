//
//  Workflow.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 28.05.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation

class Workflow<T> {
	init(middleware: AnyWorkflowMiddleware<T>, task: CloudTask, constraint: WorkflowConstraint) {
		self.middleware = middleware
		self.task = task
		self.constraint = constraint
	}

	let middleware: AnyWorkflowMiddleware<T>
	let task: CloudTask
	let constraint: WorkflowConstraint
}
