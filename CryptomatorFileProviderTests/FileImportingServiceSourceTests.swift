//
//  FileImportingServiceSourceTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 24.05.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Dependencies
import XCTest
@testable import CryptomatorCommonCore
@testable import CryptomatorFileProvider

@MainActor
class FileImportingServiceSourceTests: XCTestCase {
	var serviceSource: FileImportingServiceSource!
	var notificatorMock: FileProviderNotificatorTypeMock!
	var adapterProvidingMock: FileProviderAdapterProvidingMock!
	var urlProviderMock: LocalURLProviderMock!
	var fullVersionCheckerMock: FullVersionCheckerMock!
	var taskRegistratorMock: SessionTaskRegistratorMock!
	let dbPath = FileManager.default.temporaryDirectory
	let domain = NSFileProviderDomain(identifier: .test, displayName: "Foo", pathRelativeToDocumentStorage: "/")
	let itemStub = FileProviderItem(metadata: .init(name: "Foo", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, isPlaceholderItem: false), domainIdentifier: .test)

	override func setUp() async throws {
		try await super.setUp()
		notificatorMock = FileProviderNotificatorTypeMock()
		urlProviderMock = LocalURLProviderMock()
		adapterProvidingMock = FileProviderAdapterProvidingMock()
		fullVersionCheckerMock = FullVersionCheckerMock()
		fullVersionCheckerMock.isFullVersion = true
		taskRegistratorMock = SessionTaskRegistratorMock()
		serviceSource = withDependencies {
			$0.fullVersionChecker = fullVersionCheckerMock
		} operation: {
			FileImportingServiceSource(domain: domain,
			                           notificator: notificatorMock,
			                           dbPath: dbPath,
			                           delegate: urlProviderMock,
			                           adapterManager: adapterProvidingMock,
			                           taskRegistrator: taskRegistratorMock)
		}
	}

	func testGetItemIdentifier() async throws {
		let cloudPath = "/foo/bar"
		let adapterMock = FileProviderAdapterTypeMock()
		let expectedItemIdentifier = NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: 2)
		adapterMock.getItemIdentifierForReturnValue = expectedItemIdentifier
		adapterProvidingMock.getAdapterForDomainDbPathDelegateNotificatorTaskRegistratorReturnValue = adapterMock
		let rawItemIdentifier = try await fileImporting.getIdentifierForItem(at: cloudPath)
		let itemIdentifier = NSFileProviderItemIdentifier(rawValue: rawItemIdentifier)

		XCTAssertEqual(expectedItemIdentifier, itemIdentifier)
		assertAdapterProvidingMockGetAdapterCalled()
	}

	func testGetItemIdentifierForLockedVault() async {
		let cloudPath = "/foo/bar"
		adapterProvidingMock.getAdapterForDomainDbPathDelegateNotificatorTaskRegistratorThrowableError = UnlockMonitorError.defaultLock
		let expectedWrappedError = ErrorWrapper.wrapError(UnlockMonitorError.defaultLock, domain: domain)
		await XCTAssertThrowsAsyncError(try await fileImporting.getIdentifierForItem(at: cloudPath)) { error in
			XCTAssertEqual(expectedWrappedError._nsError, error as NSError)
		}
	}

	func testGetItemIdentifierForTrial() async throws {
		fullVersionCheckerMock.isFullVersion = false
		try await testGetItemIdentifier()
	}

	func testImportFile() async throws {
		let adapterMock = FileProviderAdapterTypeMock()
		let parentItemIdentifier = NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: 2)

		adapterProvidingMock.getAdapterForDomainDbPathDelegateNotificatorTaskRegistratorReturnValue = adapterMock
		let itemStub = itemStub
		adapterMock.importDocumentAtToParentItemIdentifierCompletionHandlerClosure = { _, _, completion in
			completion(itemStub, nil)
		}
		let localURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		try await fileImporting.importFile(at: localURL, toParentItemIdentifier: parentItemIdentifier.rawValue)
		let adapterMockReceivedArguments = adapterMock.importDocumentAtToParentItemIdentifierCompletionHandlerReceivedArguments
		XCTAssertEqual(1, adapterMock.importDocumentAtToParentItemIdentifierCompletionHandlerCallsCount)
		XCTAssertEqual(localURL, adapterMockReceivedArguments?.fileURL)
		XCTAssertEqual(parentItemIdentifier, adapterMockReceivedArguments?.parentItemIdentifier)
		assertAdapterProvidingMockGetAdapterCalled()
	}

	func testImportFileFailWithFilenameCollisionErrorWithoutAssociatedItem() async {
		let adapterMock = FileProviderAdapterTypeMock()
		let parentItemIdentifier = NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: 2)

		adapterProvidingMock.getAdapterForDomainDbPathDelegateNotificatorTaskRegistratorReturnValue = adapterMock
		let itemStub = itemStub
		adapterMock.importDocumentAtToParentItemIdentifierCompletionHandlerClosure = { _, _, completion in
			completion(nil, NSError.fileProviderErrorForCollision(with: itemStub))
		}
		let localURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		// Throws a plain filenameCollision error without the itemStub - necessary for XPC as FileProviderItem does not support secure coding
		await XCTAssertThrowsAsyncError(try await fileImporting.importFile(at: localURL, toParentItemIdentifier: parentItemIdentifier.rawValue)) { error in
			XCTAssertEqual(NSFileProviderError(.filenameCollision) as NSError, error as NSError)
		}
		let adapterMockReceivedArguments = adapterMock.importDocumentAtToParentItemIdentifierCompletionHandlerReceivedArguments
		XCTAssertEqual(1, adapterMock.importDocumentAtToParentItemIdentifierCompletionHandlerCallsCount)
		XCTAssertEqual(localURL, adapterMockReceivedArguments?.fileURL)
		XCTAssertEqual(parentItemIdentifier, adapterMockReceivedArguments?.parentItemIdentifier)
		assertAdapterProvidingMockGetAdapterCalled()
	}

	func testImportFileForLockedVault() async {
		let localURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		let parentItemIdentifier = NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: 2)
		adapterProvidingMock.getAdapterForDomainDbPathDelegateNotificatorTaskRegistratorThrowableError = UnlockMonitorError.defaultLock
		let expectedWrappedError = ErrorWrapper.wrapError(UnlockMonitorError.defaultLock, domain: domain)
		await XCTAssertThrowsAsyncError(try await fileImporting.importFile(at: localURL, toParentItemIdentifier: parentItemIdentifier.rawValue)) { error in
			XCTAssertEqual(expectedWrappedError._nsError, error as NSError)
		}
	}

	func testImportFileForTrial() async {
		fullVersionCheckerMock.isFullVersion = false
		let localURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		let parentItemIdentifier = NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: 2)
		let expectedWrappedError = XPCErrorHelper.bridgeError(FileImportingServiceSourceError.missingPremium)
		await XCTAssertThrowsAsyncError(try await fileImporting.importFile(at: localURL, toParentItemIdentifier: parentItemIdentifier.rawValue)) { error in
			XCTAssertEqual(expectedWrappedError as NSError, error as NSError)
		}
	}

	private var fileImporting: FileImporting {
		return serviceSource
	}

	private func assertAdapterProvidingMockGetAdapterCalled() {
		let adapterProviderManagerReceivedArguments = adapterProvidingMock.getAdapterForDomainDbPathDelegateNotificatorTaskRegistratorReceivedArguments
		XCTAssertEqual(domain, adapterProviderManagerReceivedArguments?.domain)
		XCTAssertEqual(dbPath, adapterProviderManagerReceivedArguments?.dbPath)
		XCTAssert(urlProviderMock === adapterProviderManagerReceivedArguments?.delegate)
		XCTAssert(notificatorMock === adapterProviderManagerReceivedArguments?.notificator)
	}
}
