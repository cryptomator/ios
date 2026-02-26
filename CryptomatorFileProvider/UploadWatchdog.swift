//
//  UploadWatchdog.swift
//  CryptomatorFileProvider
//
//  Created by Tobias Hagemann.
//  Copyright © 2026 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import Foundation

protocol UploadWatchdogType: AnyObject {
	func start()
	func stop()
}

class UploadWatchdog: UploadWatchdogType {
	private let uploadTaskManager: UploadTaskManager
	private let retryHandler: (Int64) -> Void
	private let errorHandler: (Int64) -> Void
	private let timerInterval: TimeInterval
	private let staleThreshold: TimeInterval
	private let queue: DispatchQueue
	private var timer: DispatchSourceTimer?

	init(uploadTaskManager: UploadTaskManager,
	     timerInterval: TimeInterval = 45,
	     staleThreshold: TimeInterval = 120,
	     retryHandler: @escaping (Int64) -> Void,
	     errorHandler: @escaping (Int64) -> Void) {
		self.uploadTaskManager = uploadTaskManager
		self.timerInterval = timerInterval
		self.staleThreshold = staleThreshold
		self.retryHandler = retryHandler
		self.errorHandler = errorHandler
		self.queue = DispatchQueue(label: "UploadWatchdog", qos: .utility)
	}

	func start() {
		stop()
		let timer = DispatchSource.makeTimerSource(queue: queue)
		timer.schedule(deadline: .now() + timerInterval, repeating: timerInterval)
		timer.setEventHandler { [weak self] in
			self?.checkForStaleUploads()
		}
		self.timer = timer
		timer.resume()
		DDLogInfo("UploadWatchdog started (interval: \(timerInterval)s, staleThreshold: \(staleThreshold)s)")
	}

	func stop() {
		timer?.cancel()
		timer = nil
	}

	deinit {
		stop()
	}

	private func checkForStaleUploads() {
		let staleSince = Date().addingTimeInterval(-staleThreshold)
		let staleRecords: [UploadTaskRecord]
		do {
			staleRecords = try uploadTaskManager.getStaleUploadTaskRecords(staleSince: staleSince)
		} catch {
			DDLogError("UploadWatchdog - failed to query stale upload task records: \(error)")
			return
		}
		guard !staleRecords.isEmpty else {
			return
		}
		DDLogInfo("UploadWatchdog - found \(staleRecords.count) stale upload(s)")
		for record in staleRecords {
			retryHandler(record.correspondingItem)
		}
	}
}
