//
//  FileImportingServiceSourceTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 24.05.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import XCTest
@testable import CryptomatorFileProvider
@testable import Promises

class FileImportingServiceSourceTests: XCTestCase {
	var serviceSource: FileImportingServiceSource!
	var notificatorMock: FileProviderNotificatorTypeMock!
	var adapterProvidingMock: FileProviderAdapterProvidingMock!
	var urlProviderMock: LocalURLProviderMock!
	let dbPath = FileManager.default.temporaryDirectory
	let domain = NSFileProviderDomain(identifier: .test, displayName: "Foo", pathRelativeToDocumentStorage: "/")
	let itemStub = FileProviderItem(metadata: .init(name: "Foo", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, cloudPath: CloudPath("/foo"), isPlaceholderItem: false), domainIdentifier: .test)

	override func setUpWithError() throws {
		notificatorMock = FileProviderNotificatorTypeMock()
		urlProviderMock = LocalURLProviderMock()
		adapterProvidingMock = FileProviderAdapterProvidingMock()

		serviceSource = FileImportingServiceSource(domain: domain,
		                                           notificator: notificatorMock,
		                                           dbPath: dbPath,
		                                           delegate: urlProviderMock,
		                                           adapterManager: adapterProvidingMock)
	}

	func testGetItemIdentifier() throws {
		let cloudPath = "/foo/bar"
		let adapterMock = FileProviderAdapterTypeMock()
		let expectedItemIdentifier = NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: 2)
		adapterMock.getItemIdentifierForReturnValue = Promise(expectedItemIdentifier)
		adapterProvidingMock.getAdapterForDomainDbPathDelegateNotificatorReturnValue = adapterMock
		let itemIdentifierPromise = serviceSource.getIdentifierForItem(at: cloudPath)
		wait(for: itemIdentifierPromise, timeout: 1.0)
		let rawItemIdentifier = try XCTUnwrap(itemIdentifierPromise.value)
		let itemIdentifier = NSFileProviderItemIdentifier(rawValue: rawItemIdentifier as String)

		XCTAssertEqual(expectedItemIdentifier, itemIdentifier)
		assertAdapterProvidingMockGetAdapterCalled()
	}

	func testGetItemIdentifierForLockedVault() throws {
		let cloudPath = "/foo/bar"
		adapterProvidingMock.getAdapterForDomainDbPathDelegateNotificatorThrowableError = UnlockMonitorError.defaultLock
		let itemIdentifierPromise = serviceSource.getIdentifierForItem(at: cloudPath)
		let expectedWrappedError = ErrorWrapper.wrapError(UnlockMonitorError.defaultLock, domain: domain)
		XCTAssertRejects(itemIdentifierPromise, with: expectedWrappedError._nsError)
	}

	func testImportFile() throws {
		let adapterMock = FileProviderAdapterTypeMock()
		let parentItemIdentifier = NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: 2)

		adapterProvidingMock.getAdapterForDomainDbPathDelegateNotificatorReturnValue = adapterMock
		adapterMock.importDocumentAtToParentItemIdentifierCompletionHandlerClosure = { _, _, completion in
			completion(self.itemStub, nil)
		}
		let localURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		let importFilePromise = serviceSource.importFile(at: localURL, toParentItemIdentifier: parentItemIdentifier.rawValue)
		wait(for: importFilePromise, timeout: 1.0)
		let adapterMockReceivedArguments = adapterMock.importDocumentAtToParentItemIdentifierCompletionHandlerReceivedArguments
		XCTAssertEqual(1, adapterMock.importDocumentAtToParentItemIdentifierCompletionHandlerCallsCount)
		XCTAssertEqual(localURL, adapterMockReceivedArguments?.fileURL)
		XCTAssertEqual(parentItemIdentifier, adapterMockReceivedArguments?.parentItemIdentifier)
		assertAdapterProvidingMockGetAdapterCalled()
	}

	func testImportFileFailWithFilenameCollisionErrorWithoutAssociatedItem() throws {
		let adapterMock = FileProviderAdapterTypeMock()
		let parentItemIdentifier = NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: 2)

		adapterProvidingMock.getAdapterForDomainDbPathDelegateNotificatorReturnValue = adapterMock
		adapterMock.importDocumentAtToParentItemIdentifierCompletionHandlerClosure = { _, _, completion in
			completion(nil, NSError.fileProviderErrorForCollision(with: self.itemStub))
		}
		let localURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		let importFilePromise = serviceSource.importFile(at: localURL, toParentItemIdentifier: parentItemIdentifier.rawValue)
		// Rejects with plain filenameCollision error without the itemStub - necessary for XPC as FileProviderItem does not support secure coding
		XCTAssertRejects(importFilePromise, with: NSFileProviderError(.filenameCollision))
		let adapterMockReceivedArguments = adapterMock.importDocumentAtToParentItemIdentifierCompletionHandlerReceivedArguments
		XCTAssertEqual(1, adapterMock.importDocumentAtToParentItemIdentifierCompletionHandlerCallsCount)
		XCTAssertEqual(localURL, adapterMockReceivedArguments?.fileURL)
		XCTAssertEqual(parentItemIdentifier, adapterMockReceivedArguments?.parentItemIdentifier)
		assertAdapterProvidingMockGetAdapterCalled()
	}

	func testImportFileForLockedVault() throws {
		let localURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		let parentItemIdentifier = NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: 2)
		adapterProvidingMock.getAdapterForDomainDbPathDelegateNotificatorThrowableError = UnlockMonitorError.defaultLock
		let importFilePromise = serviceSource.importFile(at: localURL, toParentItemIdentifier: parentItemIdentifier.rawValue)
		let expectedWrappedError = ErrorWrapper.wrapError(UnlockMonitorError.defaultLock, domain: domain)
		XCTAssertRejects(importFilePromise, with: expectedWrappedError._nsError)
	}

	private func assertAdapterProvidingMockGetAdapterCalled() {
		let adapterProviderManagerReceivedArguments = adapterProvidingMock.getAdapterForDomainDbPathDelegateNotificatorReceivedArguments
		XCTAssertEqual(domain, adapterProviderManagerReceivedArguments?.domain)
		XCTAssertEqual(dbPath, adapterProviderManagerReceivedArguments?.dbPath)
		XCTAssert(urlProviderMock === adapterProviderManagerReceivedArguments?.delegate)
		XCTAssert(notificatorMock === adapterProviderManagerReceivedArguments?.notificator)
	}
}
