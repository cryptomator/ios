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
	private let defaultOperationQueue: OperationQueue
	private let uploadOperationQueue: OperationQueue
	private let downloadOperationQueue: OperationQueue

	init(maxParallelUploads: Int, maxParallelDownloads: Int) {
		self.uploadSemaphore = DispatchSemaphore(value: maxParallelUploads)
		self.downloadSemaphore = DispatchSemaphore(value: maxParallelDownloads)
		self.uploadOperationQueue = OperationQueue()
		uploadOperationQueue.maxConcurrentOperationCount = maxParallelUploads
		self.defaultOperationQueue = OperationQueue()
		self.downloadOperationQueue = OperationQueue()
		downloadOperationQueue.maxConcurrentOperationCount = maxParallelDownloads
	}

	func schedule<T>(_ workflow: Workflow<T>) -> Promise<T> {
		let pendingPromise = Promise<Void>.pending()
		let semaphore = getSemaphore(for: workflow.constraint)
		let operationQueue = getOperationQueue(for: workflow.constraint)
		operationQueue.addOperation {
			semaphore?.wait()
			pendingPromise.fulfill(())
		}
		return pendingPromise.then {
			return workflow.middleware.execute(task: workflow.task)
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

	private func getOperationQueue(for constraint: WorkflowConstraint) -> OperationQueue {
		switch constraint {
		case .downloadConstrained:
			return downloadOperationQueue
		case .uploadConstrained:
			return uploadOperationQueue
		case .unconstrained:
			return defaultOperationQueue
		}
	}
}
