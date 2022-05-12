//
//  InMemoryProgressManagerTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 09.05.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import XCTest
@testable import CryptomatorFileProvider

class InMemoryProgressManagerTests: XCTestCase {
	var progressManager: InMemoryProgressManager!

	override func setUpWithError() throws {
		progressManager = InMemoryProgressManager()
	}

	func testSaveProgress() {
		let progress = Progress(totalUnitCount: 10)
		let firstItemIdentifier = NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: 2)
		progressManager.saveProgress(progress, for: firstItemIdentifier)

		let secondProgress = Progress(totalUnitCount: 20)
		let secondItemIdentifier = NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: 3)
		progressManager.saveProgress(secondProgress, for: secondItemIdentifier)

		XCTAssertEqual(progress, progressManager.getProgress(for: firstItemIdentifier))
		XCTAssertEqual(secondProgress, progressManager.getProgress(for: secondItemIdentifier))
	}

	func testSaveProgressOverwritesExisting() {
		let progress = Progress(totalUnitCount: 10)
		let itemIdentifier = NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: 2)
		progressManager.saveProgress(progress, for: itemIdentifier)

		let secondProgress = Progress(totalUnitCount: 20)
		progressManager.saveProgress(secondProgress, for: itemIdentifier)
		XCTAssertEqual(secondProgress, progressManager.getProgress(for: itemIdentifier))
	}

	func testGetMissingProgress() {
		let itemIdentifier = NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: 2)
		XCTAssertNil(progressManager.getProgress(for: itemIdentifier))
	}
}
