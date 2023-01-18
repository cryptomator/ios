//
//  UploadRetryingServiceSourceTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 09.05.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import XCTest
@testable import CryptomatorFileProvider

class UploadRetryingServiceSourceTests: XCTestCase {
	var serviceSource: UploadRetryingServiceSource!
	var adapterProvidingMock: FileProviderAdapterProvidingMock!
	var urlProviderMock: LocalURLProviderMock!
	var notificatorMock: FileProviderNotificatorTypeMock!
	var progressManagerMock: ProgressManagerMock!
	let dbPath = FileManager.default.temporaryDirectory
	let testDomain = NSFileProviderDomain(identifier: .test, displayName: "Test", pathRelativeToDocumentStorage: "")

	override func setUpWithError() throws {
		adapterProvidingMock = FileProviderAdapterProvidingMock()
		urlProviderMock = LocalURLProviderMock()
		notificatorMock = FileProviderNotificatorTypeMock()
		progressManagerMock = ProgressManagerMock()

		serviceSource = UploadRetryingServiceSource(domain: testDomain,
		                                            notificator: notificatorMock,
		                                            dbPath: dbPath,
		                                            delegate: urlProviderMock,
		                                            adapterManager: adapterProvidingMock,
		                                            progressManager: progressManagerMock,
		                                            taskRegistrator: SessionTaskRegistratorMock())
	}

	override func tearDownWithError() throws {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
	}

	func testRetryUpload() throws {
		let adapterMock = FileProviderAdapterTypeMock()
		adapterProvidingMock.getAdapterForDomainDbPathDelegateNotificatorTaskRegistratorReturnValue = adapterMock
		let expectation = XCTestExpectation()
		let itemIdentifiers = [NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: 2),
		                       NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: 3)]
		serviceSource.retryUpload(for: itemIdentifiers) { error in
			XCTAssertNil(error)
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)

		XCTAssertEqual(itemIdentifiers, adapterMock.retryUploadForReceivedInvocations)
	}

	func testGetCurrentFractionalUploadProgress() throws {
		let expectation = XCTestExpectation()
		let itemIdentifier = NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: 2)
		let mockedProgress = Progress(totalUnitCount: 100)
		mockedProgress.completedUnitCount = 42
		progressManagerMock.getProgressForReturnValue = mockedProgress
		serviceSource.getCurrentFractionalUploadProgress(for: itemIdentifier) { progress in
			XCTAssertEqual(0.42, progress)
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
		XCTAssertEqual([itemIdentifier], progressManagerMock.getProgressForReceivedInvocations)
	}
}
