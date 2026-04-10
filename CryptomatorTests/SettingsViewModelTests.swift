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
@testable import Dependencies

class SettingsViewModelTests: XCTestCase {
	private var cryptomatorSettingsMock: CryptomatorSettingsMock!
	private var fileProviderConnectorMock: FileProviderConnectorMock!
	var settingsViewModel: SettingsViewModel!
	private var cacheControllerMock: CacheControllerMock!

	override func setUpWithError() throws {
		cacheControllerMock = CacheControllerMock()
		cryptomatorSettingsMock = CryptomatorSettingsMock()
		fileProviderConnectorMock = FileProviderConnectorMock()
		settingsViewModel = createSettingsViewModel()
	}

	// - MARK: Unlock Full Version / Upgrade to Lifetime

	func testNonPayingUserSeesUnlockFullVersion() {
		cryptomatorSettingsMock.hasRunningSubscription = false
		cryptomatorSettingsMock.fullVersionUnlocked = false
		settingsViewModel = createSettingsViewModel()
		guard let section = getSection(for: .unlockFullVersionSection) else {
			XCTFail("Missing unlockFullVersionSection")
			return
		}
		guard let cellViewModel = section.elements[0] as? ButtonCellViewModel<SettingsButtonAction> else {
			XCTFail("Missing cellViewModel")
			return
		}
		XCTAssertEqual(.showUnlockFullVersion, cellViewModel.action)
	}

	func testSubscriberSeesUpgradeToLifetimeInAboutSection() {
		cryptomatorSettingsMock.hasRunningSubscription = true
		cryptomatorSettingsMock.fullVersionUnlocked = false
		settingsViewModel = createSettingsViewModel()
		let unlockSection = getSection(for: .unlockFullVersionSection)
		XCTAssertNil(unlockSection, "Subscriber should not see unlockFullVersionSection")
		guard let aboutSection = getSection(for: .aboutSection) else {
			XCTFail("Missing aboutSection")
			return
		}
		let upgradeCell = aboutSection.elements.compactMap { $0 as? ButtonCellViewModel<SettingsButtonAction> }.first { $0.action == .showUpgradeToLifetime }
		XCTAssertNotNil(upgradeCell)
	}

	func testLifetimeOwnerSeesNoUpgradeToLifetime() {
		cryptomatorSettingsMock.hasRunningSubscription = false
		cryptomatorSettingsMock.fullVersionUnlocked = true
		settingsViewModel = createSettingsViewModel()
		let unlockSection = getSection(for: .unlockFullVersionSection)
		XCTAssertNil(unlockSection)
		guard let aboutSection = getSection(for: .aboutSection) else {
			XCTFail("Missing aboutSection")
			return
		}
		let upgradeCell = aboutSection.elements.compactMap { $0 as? ButtonCellViewModel<SettingsButtonAction> }.first { $0.action == .showUpgradeToLifetime }
		XCTAssertNil(upgradeCell)
	}

	func testSubscriberWithLifetimeSeesNoUpgradeToLifetime() {
		cryptomatorSettingsMock.hasRunningSubscription = true
		cryptomatorSettingsMock.fullVersionUnlocked = true
		settingsViewModel = createSettingsViewModel()
		guard let aboutSection = getSection(for: .aboutSection) else {
			XCTFail("Missing aboutSection")
			return
		}
		let upgradeCell = aboutSection.elements.compactMap { $0 as? ButtonCellViewModel<SettingsButtonAction> }.first { $0.action == .showUpgradeToLifetime }
		XCTAssertNil(upgradeCell)
	}

	// - MARK: Cache Section

	func testInitialStateOfCacheSection() {
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

	func testRefreshCacheSize() {
		let expectation = XCTestExpectation()
		let cacheSizeInBytes = 1024 * 1024
		setCacheControllerResponse(to: cacheSizeInBytes)
		settingsViewModel.refreshCacheSize().always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 5.0)
		guard let cacheSection = getSection(for: .cacheSection) else {
			XCTFail("Missing cacheSection")
			return
		}
		guard let cacheSizeCellViewModel = cacheSection.elements[0] as? LoadingWithLabelCellViewModel else {
			XCTFail("Missing cacheSizeCellViewModel")
			return
		}
		let cacheSizeDisplayText = ByteCountFormatter().string(fromByteCount: Int64(cacheSizeInBytes))
		XCTAssertEqual(cacheSizeDisplayText, cacheSizeCellViewModel.detailTitle.value)

		guard let clearCacheButtonCellViewModel = cacheSection.elements[1] as? ButtonCellViewModel<SettingsButtonAction> else {
			XCTFail("Missing clearCacheButtonCellViewModel")
			return
		}
		XCTAssertEqual(.clearCache, clearCacheButtonCellViewModel.action)
		XCTAssertTrue(clearCacheButtonCellViewModel.isEnabled.value)
		XCTAssertFalse(cacheSizeCellViewModel.isLoading.value)
	}

	func testRefreshCacheSizeForEmptyCache() {
		let expectation = XCTestExpectation()
		setCacheControllerResponse(to: 0)
		settingsViewModel.refreshCacheSize().always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 5.0)

		checkEmptyCacheBehaviour()
	}

	func testClearCache() {
		let expectation = XCTestExpectation()
		let cacheSizeInBytes = 0
		setCacheControllerResponse(to: cacheSizeInBytes)
		settingsViewModel.clearCache().always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 5.0)

		XCTAssertEqual(1, cacheControllerMock.clearCacheCallsCount)
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
		let cacheSizeDisplayText = ByteCountFormatter().string(fromByteCount: 0)
		XCTAssertEqual(cacheSizeDisplayText, cacheSizeCellViewModel.detailTitle.value)

		guard let clearCacheButtonCellViewModel = cacheSection.elements[1] as? ButtonCellViewModel<SettingsButtonAction> else {
			XCTFail("Missing clearCacheButtonCellViewModel")
			return
		}
		XCTAssertEqual(.clearCache, clearCacheButtonCellViewModel.action)
		XCTAssertFalse(clearCacheButtonCellViewModel.isEnabled.value)
	}

	// - MARK: Debug Section

	func testDisabledDebugMode() {
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

		let showDebugModeWarningRecorder = settingsViewModel.showDebugModeWarning.recordNext(1)

		// Simulate Debug toggle
		debugModeCellViewModel.isOnButtonPublisher.send(true)

		// Check showDebugModeWarning fired
		wait(for: showDebugModeWarningRecorder)

		XCTAssertFalse(cryptomatorSettingsMock.debugModeEnabled)
		checkSendLogFilesCellViewModel()
	}

	func testEnabledDebugMode() {
		let invalidationExpectation = XCTestExpectation()
		let logLevelUpdatingMock = LogLevelUpdatingMock()
		fileProviderConnectorMock.proxy = logLevelUpdatingMock
		fileProviderConnectorMock.doneHandler = {
			invalidationExpectation.fulfill()
		}
		cryptomatorSettingsMock.debugModeEnabled = true
		settingsViewModel = createSettingsViewModel()
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
		wait(for: [expectation, invalidationExpectation], timeout: 5.0)
		checkSendLogFilesCellViewModel()
		XCTAssertEqual(1, fileProviderConnectorMock.xpcInvalidationCallCount)
	}

	func testEnableDebugMode() {
		let invalidationExpectation = XCTestExpectation()
		let expectation = XCTestExpectation()
		let logLevelUpdatingMock = LogLevelUpdatingMock()
		fileProviderConnectorMock.proxy = logLevelUpdatingMock
		fileProviderConnectorMock.doneHandler = {
			invalidationExpectation.fulfill()
		}
		settingsViewModel.enableDebugMode()
		logLevelUpdatingMock.updated.then {
			XCTAssertTrue(self.cryptomatorSettingsMock.debugModeEnabled)
			self.checkLogLevelUpdatingServiceSourceCall()
			expectation.fulfill()
		}
		wait(for: [expectation, invalidationExpectation], timeout: 5.0)
		XCTAssertEqual(1, fileProviderConnectorMock.xpcInvalidationCallCount)
	}

	func testDisableDebugMode() {
		let invalidationExpectation = XCTestExpectation()
		let expectation = XCTestExpectation()
		let logLevelUpdatingMock = LogLevelUpdatingMock()
		fileProviderConnectorMock.proxy = logLevelUpdatingMock
		fileProviderConnectorMock.doneHandler = {
			invalidationExpectation.fulfill()
		}
		guard let debugSection = getSection(for: .debugSection) else {
			XCTFail("Missing debugSection")
			return
		}
		guard let debugModeCellViewModel = debugSection.elements[0] as? SwitchCellViewModel else {
			XCTFail("Missing debugModeCellViewModel")
			return
		}

		settingsViewModel.disableDebugMode()

		XCTAssertFalse(debugModeCellViewModel.isOn.value)
		logLevelUpdatingMock.updated.then {
			XCTAssertFalse(self.cryptomatorSettingsMock.debugModeEnabled)
			self.checkLogLevelUpdatingServiceSourceCall()
			expectation.fulfill()
		}
		wait(for: [expectation, invalidationExpectation], timeout: 5.0)
		XCTAssertEqual(1, fileProviderConnectorMock.xpcInvalidationCallCount)
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
		XCTAssertEqual(LocalizedString.getValue("settings.sendLogFile"), sendLogFilesCellViewModel.title.value)
		XCTAssertEqual(.sendLogFile, sendLogFilesCellViewModel.action)
	}

	private func checkLogLevelUpdatingServiceSourceCall() {
		XCTAssertEqual(.logLevelUpdating, fileProviderConnectorMock.passedServiceName)
		XCTAssertNil(fileProviderConnectorMock.passedDomain)
		XCTAssertNil(fileProviderConnectorMock.passedDomainIdentifier)
	}

	private func getSection(for identifier: SettingsSection) -> Section<SettingsSection>? {
		return settingsViewModel.sections.filter({ $0.id == identifier }).first
	}

	private func setCacheControllerResponse(to totalCacheSizeInBytes: Int) {
		cacheControllerMock.getLocalCacheSizeInBytesReturnValue = Promise(totalCacheSizeInBytes)
	}

	private func createSettingsViewModel() -> SettingsViewModel {
		withDependencies {
			$0.fileProviderConnector = fileProviderConnectorMock
			$0.cacheController = cacheControllerMock
		} operation: {
			SettingsViewModel(cryptomatorSettings: cryptomatorSettingsMock)
		}
	}
}

private final class CacheControllerMock: CacheControlling {
	var getLocalCacheSizeInBytesCallsCount = 0
	var getLocalCacheSizeInBytesReturnValue = Promise(0)
	var clearCacheCallsCount = 0
	var clearCacheReturnValue = Promise(())

	func getLocalCacheSizeInBytes() -> Promise<Int> {
		getLocalCacheSizeInBytesCallsCount += 1
		return getLocalCacheSizeInBytesReturnValue
	}

	func clearCache() -> Promise<Void> {
		clearCacheCallsCount += 1
		return clearCacheReturnValue
	}
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
