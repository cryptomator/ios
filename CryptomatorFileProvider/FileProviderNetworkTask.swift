//
//  FileProviderNetworkTask.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 17.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Foundation

class FileProviderNetworkTask: URLSessionTask {
	private let taskProgress: Progress
	private var taskState: URLSessionTask.State

	init(with taskProgress: Progress) {
		self.taskProgress = taskProgress
		self.taskState = .suspended
	}

	override func resume() {
		taskState = .running
	}

	override func suspend() {
		taskState = .suspended
	}

	override func cancel() {
		taskState = .canceling
	}

	override var progress: Progress {
		return taskProgress
	}

	override var countOfBytesReceived: Int64 {
		return 210
	}

	override var countOfBytesExpectedToReceive: Int64 {
		return 410
	}

	override var countOfBytesExpectedToSend: Int64 {
		return 410
	}

	override var countOfBytesSent: Int64 {
		return 210
	}

	override var taskIdentifier: Int {
		return 1
	}

	override var state: URLSessionTask.State {
		return taskState
	}

	override var originalRequest: URLRequest? {
		return nil
	}

	override var currentRequest: URLRequest? {
		return nil
	}

	override var response: URLResponse? {
		return nil
	}

	override var error: Error? {
		return nil
	}

	override var countOfBytesClientExpectsToSend: Int64 {
		get {
			return 410
		}
		set {}
	}

	override var countOfBytesClientExpectsToReceive: Int64 {
		get {
			return 410
		}
		set {}
	}
}
