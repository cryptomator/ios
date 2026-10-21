//
//  SettingsViewModelTests.swift
//  CryptomatorTests
//
//  Created by Philipp Schmid on 06.10.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Dependencies
import XCTest
@testable import Cryptomator
@testable import CryptomatorCommonCore
@testable import CryptomatorFileProvider

@MainActor
class SettingsViewModelTests: XCTestCase {
	private var cryptomatorSettingsMock: CryptomatorSettingsMock!
	private var fileProviderConnectorMock: FileProviderConnectorMock!
	var settingsViewModel: SettingsViewModel!
	private var cacheControllerMock: CacheControllerMock!

	override func setUp() async throws {
		try await super.setUp()
		cacheControllerMock = CacheControllerMock()
		cryptomatorSettingsMock = CryptomatorSettingsMock()
		fileProviderConnectorMock = FileProviderConnectorMock()
	}

	// - MARK: Unlock Full Version / Upgrade to Lifetime

	func testNonPayingUserSeesUnlockFullVersion() {
		withDependencies {
			$0.fileProviderConnector = fileProviderConnectorMock
			$0.cacheController = cacheControllerMock
		} operation: {
			self.cryptomatorSettingsMock.hasRunningSubscription = false
			self.cryptomatorSettingsMock.fullVersionUnlocked = false
			self.settingsViewModel = self.createSettingsViewModel()
			guard let section = self.getSection(for: .unlockFullVersionSection) else {
				XCTFail("Missing unlockFullVersionSection")
				return
			}
			guard let cellViewModel = section.elements[0] as? ButtonCellViewModel<SettingsButtonAction> else {
				XCTFail("Missing cellViewModel")
				return
			}
			XCTAssertEqual(.showUnlockFullVersion, cellViewModel.action)
		}
	}

	func testSubscriberSeesUpgradeToLifetimeInAboutSection() {
		withDependencies {
			$0.fileProviderConnector = fileProviderConnectorMock
			$0.cacheController = cacheControllerMock
		} operation: {
			self.cryptomatorSettingsMock.hasRunningSubscription = true
			self.cryptomatorSettingsMock.fullVersionUnlocked = false
			self.settingsViewModel = self.createSettingsViewModel()
			let unlockSection = self.getSection(for: .unlockFullVersionSection)
			XCTAssertNil(unlockSection, "Subscriber should not see unlockFullVersionSection")
			guard let aboutSection = self.getSection(for: .aboutSection) else {
				XCTFail("Missing aboutSection")
				return
			}
			let upgradeCell = aboutSection.elements.compactMap { $0 as? ButtonCellViewModel<SettingsButtonAction> }.first { $0.action == .showUpgradeToLifetime }
			XCTAssertNotNil(upgradeCell)
		}
	}

	func testLifetimeOwnerSeesNoUpgradeToLifetime() {
		withDependencies {
			$0.fileProviderConnector = fileProviderConnectorMock
			$0.cacheController = cacheControllerMock
		} operation: {
			self.cryptomatorSettingsMock.hasRunningSubscription = false
			self.cryptomatorSettingsMock.fullVersionUnlocked = true
			self.settingsViewModel = self.createSettingsViewModel()
			let unlockSection = self.getSection(for: .unlockFullVersionSection)
			XCTAssertNil(unlockSection)
			guard let aboutSection = self.getSection(for: .aboutSection) else {
				XCTFail("Missing aboutSection")
				return
			}
			let upgradeCell = aboutSection.elements.compactMap { $0 as? ButtonCellViewModel<SettingsButtonAction> }.first { $0.action == .showUpgradeToLifetime }
			XCTAssertNil(upgradeCell)
		}
	}

	func testSubscriberWithLifetimeSeesNoUpgradeToLifetime() {
		withDependencies {
			$0.fileProviderConnector = fileProviderConnectorMock
			$0.cacheController = cacheControllerMock
		} operation: {
			self.cryptomatorSettingsMock.hasRunningSubscription = true
			self.cryptomatorSettingsMock.fullVersionUnlocked = true
			self.settingsViewModel = self.createSettingsViewModel()
			guard let aboutSection = self.getSection(for: .aboutSection) else {
				XCTFail("Missing aboutSection")
				return
			}
			let upgradeCell = aboutSection.elements.compactMap { $0 as? ButtonCellViewModel<SettingsButtonAction> }.first { $0.action == .showUpgradeToLifetime }
			XCTAssertNil(upgradeCell)
		}
	}

	// - MARK: Cache Section

	func testInitialStateOfCacheSection() {
		withDependencies {
			$0.fileProviderConnector = fileProviderConnectorMock
			$0.cacheController = cacheControllerMock
		} operation: {
			self.settingsViewModel = self.createSettingsViewModel()
			guard let cacheSection = self.getSection(for: .cacheSection) else {
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
	}

	func testRefreshCacheSize() async throws {
		settingsViewModel = withDependencies {
			$0.fileProviderConnector = fileProviderConnectorMock
			$0.cacheController = cacheControllerMock
		} operation: {
			createSettingsViewModel()
		}
		let cacheSizeInBytes = 1024 * 1024
		setCacheControllerResponse(to: cacheSizeInBytes)
		try await settingsViewModel.refreshCacheSize()
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

	func testRefreshCacheSizeForEmptyCache() async throws {
		settingsViewModel = withDependencies {
			$0.fileProviderConnector = fileProviderConnectorMock
			$0.cacheController = cacheControllerMock
		} operation: {
			createSettingsViewModel()
		}
		setCacheControllerResponse(to: 0)
		try await settingsViewModel.refreshCacheSize()

		checkEmptyCacheBehaviour()
	}

	func testClearCache() async throws {
		settingsViewModel = withDependencies {
			$0.fileProviderConnector = fileProviderConnectorMock
			$0.cacheController = cacheControllerMock
		} operation: {
			createSettingsViewModel()
		}
		let cacheSizeInBytes = 0
		setCacheControllerResponse(to: cacheSizeInBytes)
		try await settingsViewModel.clearCache()

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
		withDependencies {
			$0.fileProviderConnector = fileProviderConnectorMock
			$0.cacheController = cacheControllerMock
		} operation: {
			self.cryptomatorSettingsMock.debugModeEnabled = false
			self.settingsViewModel = self.createSettingsViewModel()
			guard let debugSection = self.getSection(for: .debugSection) else {
				XCTFail("Missing debugSection")
				return
			}
			guard let debugModeCellViewModel = debugSection.elements[0] as? SwitchCellViewModel else {
				XCTFail("Missing debugModeCellViewModel")
				return
			}
			XCTAssertFalse(debugModeCellViewModel.isOn.value)
			XCTAssertTrue(debugModeCellViewModel.isEnabled.value)

			self.checkSendLogFilesCellViewModel()

			let showDebugModeWarningRecorder = self.settingsViewModel.showDebugModeWarning.recordNext(1)

			debugModeCellViewModel.isOnButtonPublisher.send(true)

			self.wait(for: showDebugModeWarningRecorder)

			XCTAssertFalse(self.cryptomatorSettingsMock.debugModeEnabled)
			self.checkSendLogFilesCellViewModel()
		}
	}

	func testEnabledDebugMode() async {
		let invalidationExpectation = XCTestExpectation()
		let logLevelUpdatingMock = LogLevelUpdatingMock()
		fileProviderConnectorMock.proxy = logLevelUpdatingMock
		fileProviderConnectorMock.doneHandler = {
			invalidationExpectation.fulfill()
		}
		cryptomatorSettingsMock.debugModeEnabled = true
		settingsViewModel = withDependencies {
			$0.fileProviderConnector = fileProviderConnectorMock
			$0.cacheController = cacheControllerMock
		} operation: {
			createSettingsViewModel()
		}
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

		debugModeCellViewModel.isOnButtonPublisher.send(false)
		await fulfillment(of: [logLevelUpdatingMock.updated, invalidationExpectation], timeout: 5.0)
		XCTAssertFalse(cryptomatorSettingsMock.debugModeEnabled)
		checkLogLevelUpdatingServiceSourceCall()
		checkSendLogFilesCellViewModel()
		XCTAssertEqual(1, fileProviderConnectorMock.xpcInvalidationCallCount)
	}

	func testEnableDebugMode() async {
		settingsViewModel = withDependencies {
			$0.fileProviderConnector = fileProviderConnectorMock
			$0.cacheController = cacheControllerMock
		} operation: {
			createSettingsViewModel()
		}
		let invalidationExpectation = XCTestExpectation()
		let logLevelUpdatingMock = LogLevelUpdatingMock()
		fileProviderConnectorMock.proxy = logLevelUpdatingMock
		fileProviderConnectorMock.doneHandler = {
			invalidationExpectation.fulfill()
		}
		settingsViewModel.enableDebugMode()
		await fulfillment(of: [logLevelUpdatingMock.updated, invalidationExpectation], timeout: 5.0)
		XCTAssertTrue(cryptomatorSettingsMock.debugModeEnabled)
		checkLogLevelUpdatingServiceSourceCall()
		XCTAssertEqual(1, fileProviderConnectorMock.xpcInvalidationCallCount)
	}

	func testDisableDebugMode() async {
		settingsViewModel = withDependencies {
			$0.fileProviderConnector = fileProviderConnectorMock
			$0.cacheController = cacheControllerMock
		} operation: {
			createSettingsViewModel()
		}
		let invalidationExpectation = XCTestExpectation()
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
		await fulfillment(of: [logLevelUpdatingMock.updated, invalidationExpectation], timeout: 5.0)
		XCTAssertFalse(cryptomatorSettingsMock.debugModeEnabled)
		checkLogLevelUpdatingServiceSourceCall()
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
		cacheControllerMock.getLocalCacheSizeInBytesReturnValue = totalCacheSizeInBytes
	}

	private func createSettingsViewModel() -> SettingsViewModel {
		SettingsViewModel(cryptomatorSettings: cryptomatorSettingsMock)
	}
}

/// @unchecked Sendable: test double, never touched concurrently
private final class CacheControllerMock: CacheControlling, @unchecked Sendable {
	var getLocalCacheSizeInBytesCallsCount = 0
	var getLocalCacheSizeInBytesReturnValue = 0
	var clearCacheCallsCount = 0

	func getLocalCacheSizeInBytes() async throws -> Int {
		getLocalCacheSizeInBytesCallsCount += 1
		return getLocalCacheSizeInBytesReturnValue
	}

	func clearCache() async throws {
		clearCacheCallsCount += 1
	}
}

private class LogLevelUpdatingMock: LogLevelUpdating {
	var serviceName: NSFileProviderServiceName {
		fatalError("Not mocked")
	}

	let updated = XCTestExpectation(description: "Log level updated")

	func logLevelUpdated() {
		updated.fulfill()
	}

	func makeListenerEndpoint() throws -> NSXPCListenerEndpoint {
		throw MockError.notMocked
	}
}
