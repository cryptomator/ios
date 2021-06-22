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
	private let uploadSemaphore: DispatchSemaphore
	private let downloadSemaphore: DispatchSemaphore

	init(maxParallelUploads: Int, maxParallelDownloads: Int) {
		self.uploadSemaphore = DispatchSemaphore(value: maxParallelUploads)
		self.downloadSemaphore = DispatchSemaphore(value: maxParallelDownloads)
	}

	func schedule<T>(_ workflow: Workflow<T>) -> Promise<T> {
		let semaphore = getSemaphore(for: workflow.constraint)
		return Promise<Void>(on: DispatchQueue.global(qos: .userInitiated)) { fulfill, _ in
			semaphore?.wait()
			fulfill(())
		}.then {
			workflow.middleware.execute(task: workflow.task)
		}.always {
			semaphore?.signal()
		}
	}

	private func getSemaphore(for constraint: WorkflowConstraint) -> DispatchSemaphore? {
		switch constraint {
		case .downloadConstrained:
			return downloadSemaphore
		case .uploadConstrained:
			return uploadSemaphore
		case .unconstrained:
			return nil
		}
	}
}
