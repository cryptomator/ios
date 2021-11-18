//
//  SettingsViewModelTests.swift
//  CryptomatorTests
//
//  Created by Philipp Schmid on 06.10.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Promises
import XCTest
@testable import Cryptomator
@testable import CryptomatorCommonCore
@testable import CryptomatorFileProvider

class SettingsViewModelTests: XCTestCase {
	private var cacheManagerMock: FileProviderCacheManagerMock!
	private var cryptomatorSettingsMock: CryptomatorSettingsMock!
	private var fileProviderConnectorMock: FileProviderConnectorMock!
	var settingsViewModel: SettingsViewModel!

	override func setUpWithError() throws {
		cacheManagerMock = FileProviderCacheManagerMock()
		cryptomatorSettingsMock = CryptomatorSettingsMock()
		fileProviderConnectorMock = FileProviderConnectorMock()
		settingsViewModel = SettingsViewModel(cacheManager: cacheManagerMock, cryptomatorSetttings: cryptomatorSettingsMock, fileProviderConnector: fileProviderConnectorMock)
	}

	// - MARK: Cache Section

	func testInitialStateOfCacheSection() throws {
		guard let cacheSection = getSection(for: .cacheSection) else {
			XCTFail("Missing cacheSection")
			return
		}
		guard let cacheSizeCellViewModel = cacheSection.elements[0] as? LoadingWithLabelCellViewModel else {
			XCTFail("Missing cacheSizeCellViewModel")
			return
		}

		XCTAssertFalse(cacheSizeCellViewModel.isLoading.value)
		XCTAssertEqual(LocalizedString.getValue("settings.cacheSize"), cacheSizeCellViewModel.title.value)
		XCTAssertNil(cacheSizeCellViewModel.detailTitle.value)

		guard let clearCacheButtonCellViewModel = cacheSection.elements[1] as? ButtonCellViewModel<SettingsButtonAction> else {
			XCTFail("Missing clearCacheButtonCellViewModel")
			return
		}
		XCTAssertEqual(.clearCache, clearCacheButtonCellViewModel.action)
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
		guard let cacheSection = getSection(for: .cacheSection) else {
			XCTFail("Missing cacheSection")
			return
		}
		guard let cacheSizeCellViewModel = cacheSection.elements[0] as? LoadingWithLabelCellViewModel else {
			XCTFail("Missing cacheSizeCellViewModel")
			return
		}
		XCTAssertEqual("1 MB", cacheSizeCellViewModel.detailTitle.value)

		guard let clearCacheButtonCellViewModel = cacheSection.elements[1] as? ButtonCellViewModel<SettingsButtonAction> else {
			XCTFail("Missing clearCacheButtonCellViewModel")
			return
		}
		XCTAssertEqual(.clearCache, clearCacheButtonCellViewModel.action)
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
		guard let cacheSection = getSection(for: .cacheSection) else {
			XCTFail("Missing cacheSection")
			return
		}
		guard let cacheSizeCellViewModel = cacheSection.elements[0] as? LoadingWithLabelCellViewModel else {
			XCTFail("Missing cacheSizeCellViewModel")
			return
		}
		XCTAssertEqual("Zero KB", cacheSizeCellViewModel.detailTitle.value)

		guard let clearCacheButtonCellViewModel = cacheSection.elements[1] as? ButtonCellViewModel<SettingsButtonAction> else {
			XCTFail("Missing clearCacheButtonCellViewModel")
			return
		}
		XCTAssertEqual(.clearCache, clearCacheButtonCellViewModel.action)
		XCTAssertFalse(clearCacheButtonCellViewModel.isEnabled.value)
	}

	// - MARK: Debug Section

	func testDisabledDebugMode() {
		let logLevelUpdatingMock = LogLevelUpdatingMock()
		fileProviderConnectorMock.proxy = logLevelUpdatingMock
		cryptomatorSettingsMock.debugModeEnabled = false
		guard let debugSection = getSection(for: .debugSection) else {
			XCTFail("Missing debugSection")
			return
		}
		guard let debugModeCellViewModel = debugSection.elements[0] as? SwitchCellViewModel else {
			XCTFail("Missing debugModeCellViewModel")
			return
		}
		XCTAssertFalse(debugModeCellViewModel.isOn.value)
		XCTAssertTrue(debugModeCellViewModel.isEnabled.value)

		checkSendLogFilesCellViewModel()

		// Simulate Debug toggle
		let expectation = XCTestExpectation()
		debugModeCellViewModel.isOnButtonPublisher.send(true)
		logLevelUpdatingMock.updated.then {
			XCTAssertTrue(self.cryptomatorSettingsMock.debugModeEnabled)
			self.checkLogLevelUpdatingServiceSourceCall()
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
		checkSendLogFilesCellViewModel()
	}

	func testEnabledDebugMode() {
		let logLevelUpdatingMock = LogLevelUpdatingMock()
		fileProviderConnectorMock.proxy = logLevelUpdatingMock
		cryptomatorSettingsMock.debugModeEnabled = true
		guard let debugSection = getSection(for: .debugSection) else {
			XCTFail("Missing debugSection")
			return
		}
		guard let debugModeCellViewModel = debugSection.elements[0] as? SwitchCellViewModel else {
			XCTFail("Missing debugModeCellViewModel")
			return
		}
		XCTAssertTrue(debugModeCellViewModel.isOn.value)
		XCTAssertTrue(debugModeCellViewModel.isEnabled.value)

		checkSendLogFilesCellViewModel()

		// Simulate Debug toggle
		let expectation = XCTestExpectation()
		debugModeCellViewModel.isOnButtonPublisher.send(false)
		logLevelUpdatingMock.updated.then {
			XCTAssertFalse(self.cryptomatorSettingsMock.debugModeEnabled)
			self.checkLogLevelUpdatingServiceSourceCall()
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
		checkSendLogFilesCellViewModel()
	}

	private func checkSendLogFilesCellViewModel() {
		guard let debugSection = getSection(for: .debugSection) else {
			XCTFail("Missing debugSection")
			return
		}
		guard let sendLogFilesCellViewModel = debugSection.elements[1] as? ButtonCellViewModel<SettingsButtonAction> else {
			XCTFail("Missing sendLogFilesCellViewModel")
			return
		}
		XCTAssertTrue(sendLogFilesCellViewModel.isEnabled.value)
		XCTAssertEqual(LocalizedString.getValue("Send Log File"), sendLogFilesCellViewModel.title.value)
		XCTAssertEqual(.sendLogFile, sendLogFilesCellViewModel.action)
	}

	private func checkLogLevelUpdatingServiceSourceCall() {
		XCTAssertEqual(LogLevelUpdatingService.name, fileProviderConnectorMock.passedServiceName)
		XCTAssertNil(fileProviderConnectorMock.passedDomain)
		XCTAssertNil(fileProviderConnectorMock.passedDomainIdentifier)
	}

	private func getSection(for identifier: SettingsSection) -> Section<SettingsSection>? {
		return settingsViewModel.sections.filter({ $0.id == identifier }).first
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

private class CryptomatorSettingsMock: CryptomatorSettings {
	var debugModeEnabled: Bool = false
}

private class LogLevelUpdatingMock: LogLevelUpdating {
	var serviceName: NSFileProviderServiceName {
		fatalError("Not mocked")
	}

	let updated = Promise<Void>.pending()

	func logLevelUpdated() {
		updated.fulfill(())
	}

	func makeListenerEndpoint() throws -> NSXPCListenerEndpoint {
		throw MockError.notMocked
	}
}
