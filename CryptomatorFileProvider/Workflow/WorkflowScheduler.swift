//
//  WorkflowScheduler.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 28.05.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation
import Promises
class WorkflowScheduler {
	func schedule<T>(_ workflow: Workflow<T>) -> Promise<T> {
		workflow.middleware.execute(task: workflow.task)
	}
}
