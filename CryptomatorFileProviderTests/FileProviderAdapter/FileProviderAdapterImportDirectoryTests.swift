//
//  FileProviderAdapterImportDirectoryTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 21.03.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import XCTest
@testable import CryptomatorFileProvider
@testable import Promises

class FileProviderAdapterImportDirectoryTests: FileProviderAdapterTestCase {
	private lazy var localFileURL = tmpDirectory.appendingPathComponent("test.txt")

	override func setUpWithError() throws {
		try super.setUpWithError()
		let fileContent = "Content"
		try fileContent.write(to: localFileURL, atomically: true, encoding: .utf8)
	}

	func testImportDirectory() throws {
		localURLProviderMock.itemIdentifierDirectoryURLForItemWithPersistentIdentifierClosure = {
			return self.tmpDirectory.appendingPathComponent($0.rawValue)
		}
		metadataManagerMock.cachedMetadata[1] = ItemMetadata(item: .init(name: "/", cloudPath: CloudPath("/"), itemType: .folder, lastModifiedDate: nil, size: nil), withParentID: 1)
		let provider = CloudProviderGraphMock()
		let scheduler = createGraphScheduler()
		let adapter = createPackageAdapter(provider: provider, scheduler: scheduler)
		var parentIdentifier: NSFileProviderItemIdentifier = .rootContainer

		for _ in 0 ..< 5 {
			parentIdentifier = try createDirectoryWithFiles(adapter: adapter, parentIdentifier: parentIdentifier).itemIdentifier
		}
		let expectation = XCTestExpectation()
		DispatchQueue.global().async {
			XCTAssertEqual(.success, scheduler.dispatchGroup.wait(timeout: .now() + 30))
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 35)
	}

	private func createDirectoryWithFiles(adapter: FileProviderAdapter, parentIdentifier: NSFileProviderItemIdentifier) throws -> NSFileProviderItem {
		let createDirectoryPromise = adapter.createDirectory(withName: "1", inParentItemIdentifier: parentIdentifier)
		wait(for: createDirectoryPromise, timeout: 10.0)
		let firstDirectoryItem = try XCTUnwrap(createDirectoryPromise.value ?? nil)

		let importDocumentPromise = adapter.importDocument(at: localFileURL, toParentItemIdentifier: firstDirectoryItem.itemIdentifier)
		wait(for: importDocumentPromise, timeout: 10.0)
		return firstDirectoryItem
	}
}

extension FileProviderAdapterType {
	func createDirectory(withName name: String, inParentItemIdentifier parentIdentifier: NSFileProviderItemIdentifier) -> Promise<NSFileProviderItem?> {
		return Promise<NSFileProviderItem?> { fulfill, reject in
			self.createDirectory(withName: name, inParentItemIdentifier: parentIdentifier, completionHandler: { item, error in
				if let error = error {
					reject(error)
				} else {
					fulfill(item)
				}
			})
		}
	}
}
