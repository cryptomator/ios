//
//  Workflow.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 28.05.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation

struct Workflow<T> {
	let middleware: AnyWorkflowMiddleware<T>
	let task: CloudTask
	let constraint: WorkflowConstraint
}
