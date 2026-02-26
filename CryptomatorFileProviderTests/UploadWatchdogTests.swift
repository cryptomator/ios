//
//  UploadWatchdogTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Tobias Hagemann.
//  Copyright © 2026 Skymatic GmbH. All rights reserved.
//

import Foundation
import XCTest
@testable import CryptomatorFileProvider

class UploadWatchdogTests: XCTestCase {
	var uploadTaskManagerMock: UploadTaskManagerMock!

	override func setUpWithError() throws {
		try super.setUpWithError()
		uploadTaskManagerMock = UploadTaskManagerMock()
	}

	func testWatchdogCallsRetryHandlerForStaleUploads() {
		let expectation = XCTestExpectation(description: "Retry handler called")
		var retriedItemIDs = [Int64]()

		let staleRecord = UploadTaskRecord(correspondingItem: 42, lastFailedUploadDate: nil, uploadErrorCode: nil, uploadErrorDomain: nil, uploadStartedAt: Date().addingTimeInterval(-200))
		uploadTaskManagerMock.getStaleUploadTaskRecordsStaleSinceReturnValue = [staleRecord]

		let watchdog = UploadWatchdog(uploadTaskManager: uploadTaskManagerMock,
		                              timerInterval: 0.1,
		                              staleThreshold: 120,
		                              retryHandler: { itemID in
		                              	retriedItemIDs.append(itemID)
		                              	expectation.fulfill()
		                              },
		                              errorHandler: { _ in })
		watchdog.start()

		wait(for: [expectation], timeout: 2.0)
		watchdog.stop()

		XCTAssertEqual([42], retriedItemIDs)
		XCTAssertTrue(uploadTaskManagerMock.getStaleUploadTaskRecordsStaleSinceCalled)
	}

	func testWatchdogDoesNothingWhenNoStaleUploads() {
		uploadTaskManagerMock.getStaleUploadTaskRecordsStaleSinceReturnValue = []

		let expectation = XCTestExpectation(description: "Timer fires")
		var retryHandlerCalled = false

		let watchdog = UploadWatchdog(uploadTaskManager: uploadTaskManagerMock,
		                              timerInterval: 0.1,
		                              staleThreshold: 120,
		                              retryHandler: { _ in
		                              	retryHandlerCalled = true
		                              },
		                              errorHandler: { _ in })
		watchdog.start()

		// Wait for at least one timer fire
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 2.0)
		watchdog.stop()

		XCTAssertFalse(retryHandlerCalled)
		XCTAssertTrue(uploadTaskManagerMock.getStaleUploadTaskRecordsStaleSinceCalled)
	}

	func testWatchdogStopsOnDeinit() {
		uploadTaskManagerMock.getStaleUploadTaskRecordsStaleSinceReturnValue = []

		var watchdog: UploadWatchdog? = UploadWatchdog(uploadTaskManager: uploadTaskManagerMock,
		                                               timerInterval: 0.1,
		                                               staleThreshold: 120,
		                                               retryHandler: { _ in },
		                                               errorHandler: { _ in })
		watchdog?.start()
		watchdog = nil

		// No crash on dealloc = success
		XCTAssertNil(watchdog)
	}
}
