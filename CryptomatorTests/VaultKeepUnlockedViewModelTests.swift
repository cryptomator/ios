//
//  VaultKeepUnlockedViewModelTests.swift
//  CryptomatorTests
//
//  Created by Philipp Schmid on 04.01.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import XCTest
@testable import Cryptomator

class VaultKeepUnlockedViewModelTests: XCTestCase {
	var vaultKeepUnlockedSettingsMock: VaultKeepUnlockedSettingsMock!
	var masterkeyCacheManagerMock: MasterkeyCacheManagerMock!
	let vaultUID = "VaultUID-12345"

	override func setUpWithError() throws {
		vaultKeepUnlockedSettingsMock = VaultKeepUnlockedSettingsMock()
		masterkeyCacheManagerMock = MasterkeyCacheManagerMock()
	}

	func testDefaultConfiguration() {
		let currentKeepUnlockedDuration = Bindable<KeepUnlockedDuration?>(KeepUnlockedDuration.twoMinutes)
		let viewModel = createViewModel(currentKeepUnlockedDuration: currentKeepUnlockedDuration)
		let expectedKeepUnlockedItems: [KeepUnlockedItem] = [
			.init(duration: .oneMinute, selected: false),
			.init(duration: .twoMinutes, selected: true),
			.init(duration: .fiveMinutes, selected: false),
			.init(duration: .tenMinutes, selected: false),
			.init(duration: .fifteenMinutes, selected: false),
			.init(duration: .thirtyMinutes, selected: false),
			.init(duration: .oneHour, selected: false),
			.init(duration: .forever, selected: false)
		]
		XCTAssertEqual(expectedKeepUnlockedItems, viewModel.items)
		XCTAssertEqual(.twoMinutes, currentKeepUnlockedDuration.value)
		XCTAssertEqual(LocalizedString.getValue("vaultDetail.keepUnlocked.title"), viewModel.title)
	}

	func testSetKeepUnlockedDuration() throws {
		let currentKeepUnlockedDuration = Bindable<KeepUnlockedDuration?>(KeepUnlockedDuration.twoMinutes)
		let viewModel = createViewModel(currentKeepUnlockedDuration: currentKeepUnlockedDuration)

		try viewModel.setKeepUnlockedDuration(to: .oneMinute)

		let expectedKeepUnlockedItems: [KeepUnlockedItem] = [
			.init(duration: .oneMinute, selected: true),
			.init(duration: .twoMinutes, selected: false),
			.init(duration: .fiveMinutes, selected: false),
			.init(duration: .tenMinutes, selected: false),
			.init(duration: .fifteenMinutes, selected: false),
			.init(duration: .thirtyMinutes, selected: false),
			.init(duration: .oneHour, selected: false),
			.init(duration: .forever, selected: false)
		]
		XCTAssertEqual(expectedKeepUnlockedItems, viewModel.items)
		XCTAssertEqual(.oneMinute, currentKeepUnlockedDuration.value)
		XCTAssertEqual(1, vaultKeepUnlockedSettingsMock.setKeepUnlockedDurationForVaultUIDCallsCount)
		let receivedArguments = vaultKeepUnlockedSettingsMock.setKeepUnlockedDurationForVaultUIDReceivedArguments
		XCTAssertEqual(vaultUID, receivedArguments?.vaultUID)
		XCTAssertEqual(KeepUnlockedDuration.oneMinute, receivedArguments?.duration)
		XCTAssertFalse(masterkeyCacheManagerMock.removeCachedMasterkeyForVaultUIDCalled)
	}

	func testSetKeepUnlockedDurationForAlreadySelectedItem() throws {
		let currentKeepUnlockedDuration = Bindable<KeepUnlockedDuration?>(KeepUnlockedDuration.oneMinute)
		let viewModel = createViewModel(currentKeepUnlockedDuration: currentKeepUnlockedDuration)

		try viewModel.setKeepUnlockedDuration(to: .oneMinute)

		let expectedKeepUnlockedItems: [KeepUnlockedItem] = [
			.init(duration: .oneMinute, selected: true),
			.init(duration: .twoMinutes, selected: false),
			.init(duration: .fiveMinutes, selected: false),
			.init(duration: .tenMinutes, selected: false),
			.init(duration: .fifteenMinutes, selected: false),
			.init(duration: .thirtyMinutes, selected: false),
			.init(duration: .oneHour, selected: false),
			.init(duration: .forever, selected: false)
		]
		XCTAssertEqual(expectedKeepUnlockedItems, viewModel.items)
		XCTAssertEqual(.oneMinute, currentKeepUnlockedDuration.value)
		XCTAssertEqual(1, vaultKeepUnlockedSettingsMock.setKeepUnlockedDurationForVaultUIDCallsCount)
		let receivedArguments = vaultKeepUnlockedSettingsMock.setKeepUnlockedDurationForVaultUIDReceivedArguments
		XCTAssertEqual(vaultUID, receivedArguments?.vaultUID)
		XCTAssertEqual(KeepUnlockedDuration.oneMinute, receivedArguments?.duration)
		XCTAssertFalse(masterkeyCacheManagerMock.removeCachedMasterkeyForVaultUIDCalled)
	}

	private func createViewModel(currentKeepUnlockedDuration: Bindable<KeepUnlockedDuration?>) -> VaultKeepUnlockedViewModel {
		return VaultKeepUnlockedViewModel(currentKeepUnlockedDuration: currentKeepUnlockedDuration, vaultUID: vaultUID, vaultKeepUnlockedSettings: vaultKeepUnlockedSettingsMock, masterkeyCacheManager: masterkeyCacheManagerMock)
	}
}
