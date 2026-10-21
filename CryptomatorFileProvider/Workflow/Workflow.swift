//
//  Workflow.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 28.05.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation

class Workflow<T> {
	init(middleware: AnyWorkflowMiddleware<T>, task: CloudTask) {
		self.middleware = middleware
		self.task = task
	}

	let middleware: AnyWorkflowMiddleware<T>
	let task: CloudTask
}
