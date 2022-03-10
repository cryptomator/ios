//
//  LocalURLProviderTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 04.03.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorFileProvider
import FileProvider
import XCTest

class LocalURLProviderTests: XCTestCase {
	let domain = NSFileProviderDomain(vaultUID: "12345", displayName: "TestDomain")
	var localURLProvider: LocalURLProvider!
	var documentStorageURLProviderMock: DocumentStorageURLProviderMock!
	var documentStorageURL: URL!
	var baseStorageDirectoryURL: URL {
		documentStorageURL.appendingPathComponent(domain.pathRelativeToDocumentStorage, isDirectory: true)
	}

	override func setUpWithError() throws {
		documentStorageURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: documentStorageURL, withIntermediateDirectories: false)
		documentStorageURLProviderMock = DocumentStorageURLProviderMock(tmpDirURL: documentStorageURL)
		localURLProvider = LocalURLProvider(domain: domain, documentStorageURLProvider: documentStorageURLProviderMock)
	}

	override func tearDownWithError() throws {
		try FileManager.default.removeItem(at: documentStorageURL)
	}

	// MARK: URL For Item

	func testURLForItemForRootContainer() throws {
		XCTAssertEqual(baseStorageDirectoryURL.path, localURLProvider.urlForItem(withPersistentIdentifier: .rootContainer, itemName: "Home")?.path)
		try assertDocumentStorageURLExcludedFromiCloudBackup()
	}

	func testURLForItemForNormalIdentifier() throws {
		let identifier = NSFileProviderItemIdentifier("2")
		let itemName = "test.txt"
		let itemIdentifierDirectory = baseStorageDirectoryURL.appendingPathComponent("2", isDirectory: true)
		let expectedItemURL = itemIdentifierDirectory.appendingPathComponent(itemName, isDirectory: false)
		XCTAssertEqual(expectedItemURL, localURLProvider.urlForItem(withPersistentIdentifier: identifier, itemName: itemName))
		try assertDocumentStorageURLExcludedFromiCloudBackup()
	}

	private func assertDocumentStorageURLExcludedFromiCloudBackup() throws {
		let resourceValues = try documentStorageURL.resourceValues(forKeys: [.isExcludedFromBackupKey])
		let documentStorageIsExcludedFromBackup = try XCTUnwrap(resourceValues.isExcludedFromBackup)
		XCTAssert(documentStorageIsExcludedFromBackup)
	}
}
