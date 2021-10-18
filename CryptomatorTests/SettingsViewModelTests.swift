//
//  SettingsViewModelTests.swift
//  CryptomatorTests
//
//  Created by Philipp Schmid on 06.10.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import Promises
import XCTest
@testable import Cryptomator
@testable import CryptomatorFileProvider

class SettingsViewModelTests: XCTestCase {
	private var cacheManagerMock: FileProviderCacheManagerMock!
	var settingsViewModel: SettingsViewModel!

	override func setUpWithError() throws {
		cacheManagerMock = FileProviderCacheManagerMock()
		settingsViewModel = SettingsViewModel(cacheManager: cacheManagerMock)
	}

	func testInitialStateOfCacheSection() throws {
		guard let cacheSizeCellViewModel = settingsViewModel.cells[.cacheSection]?[0] as? LoadingWithLabelCellViewModel else {
			XCTFail("Missing cacheSizeCellViewModel")
			return
		}

		XCTAssertFalse(cacheSizeCellViewModel.isLoading.value)
		XCTAssertEqual(LocalizedString.getValue("settings.cacheSize"), cacheSizeCellViewModel.title.value)
		XCTAssertNil(cacheSizeCellViewModel.detailTitle.value)

		guard let clearCacheButtonCellViewModel = settingsViewModel.cells[.cacheSection]?[1] else {
			XCTFail("Missing clearCacheButtonCellViewModel")
			return
		}
		XCTAssertFalse(clearCacheButtonCellViewModel.isEnabled.value)
		XCTAssertEqual(LocalizedString.getValue("settings.clearCache"), clearCacheButtonCellViewModel.title.value)
		XCTAssertNil(clearCacheButtonCellViewModel.detailTitle.value)
	}

	func testRefreshCacheSize() throws {
		let expectation = XCTestExpectation()
		cacheManagerMock.totalCacheSizeInBytes = 1024 * 1024
		settingsViewModel.refreshCacheSize().always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)

		guard let cacheSizeCellViewModel = settingsViewModel.cells[.cacheSection]?[0] as? LoadingWithLabelCellViewModel else {
			XCTFail("Missing cacheSizeCellViewModel")
			return
		}
		XCTAssertEqual("1 MB", cacheSizeCellViewModel.detailTitle.value)

		guard let clearCacheButtonCellViewModel = settingsViewModel.cells[.cacheSection]?[1] else {
			XCTFail("Missing clearCacheButtonCellViewModel")
			return
		}
		XCTAssertTrue(clearCacheButtonCellViewModel.isEnabled.value)
		XCTAssertFalse(cacheSizeCellViewModel.isLoading.value)
	}

	func testRefreshCacheSizeForEmptyCache() throws {
		let expectation = XCTestExpectation()
		settingsViewModel.refreshCacheSize().always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)

		checkEmptyCacheBehaviour()
	}

	func testClearCache() throws {
		let expectation = XCTestExpectation()
		cacheManagerMock.totalCacheSizeInBytes = 1024 * 1024
		settingsViewModel.clearCache().always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)

		XCTAssertTrue(cacheManagerMock.clearedCache)
		checkEmptyCacheBehaviour()
	}

	func checkEmptyCacheBehaviour() {
		guard let cacheSizeCellViewModel = settingsViewModel.cells[.cacheSection]?[0] else {
			XCTFail("Missing cacheSizeCellViewModel")
			return
		}
		XCTAssertEqual("Zero KB", cacheSizeCellViewModel.detailTitle.value)

		guard let clearCacheButtonCellViewModel = settingsViewModel.cells[.cacheSection]?[1] else {
			XCTFail("Missing clearCacheButtonCellViewModel")
			return
		}
		XCTAssertFalse(clearCacheButtonCellViewModel.isEnabled.value)
	}
}

private class FileProviderCacheManagerMock: FileProviderCacheManager {
	var totalCacheSizeInBytes = 0
	var clearedCache = false
	init() {
		super.init(documentStorageURLProvider: DocumentStorageURLProviderStub())
	}

	override func getTotalLocalCacheSizeInBytes() -> Promise<Int> {
		return Promise(totalCacheSizeInBytes)
	}

	override func clearCache() -> Promise<Void> {
		clearedCache = true
		totalCacheSizeInBytes = 0
		return Promise(())
	}
}

private class DocumentStorageURLProviderStub: DocumentStorageURLProvider {
	var documentStorageURL: URL {
		fatalError("not implemented")
	}
}
