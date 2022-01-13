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
	var vaultAutoLockingSettingsMock: VaultAutoLockingSettingsMock!
	var masterkeyCacheManagerMock: MasterkeyCacheManagerMock!
	let vaultUID = "VaultUID-12345"

	override func setUpWithError() throws {
		vaultAutoLockingSettingsMock = VaultAutoLockingSettingsMock()
		masterkeyCacheManagerMock = MasterkeyCacheManagerMock()
	}

	func testDefaultConfiguration() {
		let currentKeepUnlockedSetting = Bindable(KeepUnlockedSetting.twoMinutes)
		let viewModel = createViewModel(currentKeepUnlockedSetting: currentKeepUnlockedSetting)
		let expectedAutoLockItems: [AutoLockItem] = [
			.init(timeout: .off, selected: false),
			.init(timeout: .oneMinute, selected: false),
			.init(timeout: .twoMinutes, selected: true),
			.init(timeout: .fiveMinutes, selected: false),
			.init(timeout: .tenMinutes, selected: false),
			.init(timeout: .fifteenMinutes, selected: false),
			.init(timeout: .thirtyMinutes, selected: false),
			.init(timeout: .oneHour, selected: false),
			.init(timeout: .never, selected: false)
		]
		XCTAssertEqual(expectedAutoLockItems, viewModel.items)
		XCTAssertEqual(.twoMinutes, currentKeepUnlockedSetting.value)
		XCTAssertEqual(LocalizedString.getValue("vaultDetail.keepUnlocked.title"), viewModel.title)
	}

	func testSetKeepUnlockedSetting() throws {
		let currentKeepUnlockedSetting = Bindable(KeepUnlockedSetting.twoMinutes)
		let viewModel = createViewModel(currentKeepUnlockedSetting: currentKeepUnlockedSetting)

		try viewModel.setKeepUnlockedSetting(to: .oneMinute)

		let expectedAutoLockItems: [AutoLockItem] = [
			.init(timeout: .off, selected: false),
			.init(timeout: .oneMinute, selected: true),
			.init(timeout: .twoMinutes, selected: false),
			.init(timeout: .fiveMinutes, selected: false),
			.init(timeout: .tenMinutes, selected: false),
			.init(timeout: .fifteenMinutes, selected: false),
			.init(timeout: .thirtyMinutes, selected: false),
			.init(timeout: .oneHour, selected: false),
			.init(timeout: .never, selected: false)
		]
		XCTAssertEqual(expectedAutoLockItems, viewModel.items)
		XCTAssertEqual(.oneMinute, currentKeepUnlockedSetting.value)
		XCTAssertEqual(1, vaultAutoLockingSettingsMock.setKeepUnlockedSettingForVaultUIDCallsCount)
		let receivedArguments = vaultAutoLockingSettingsMock.setKeepUnlockedSettingForVaultUIDReceivedArguments
		XCTAssertEqual(vaultUID, receivedArguments?.vaultUID)
		XCTAssertEqual(KeepUnlockedSetting.oneMinute, receivedArguments?.timeout)
		XCTAssertFalse(masterkeyCacheManagerMock.removeCachedMasterkeyForVaultUIDCalled)
	}

	func testSetKeepUnlockedSettingForAlreadySelectedItem() throws {
		let currentKeepUnlockedSetting = Bindable(KeepUnlockedSetting.oneMinute)
		let viewModel = createViewModel(currentKeepUnlockedSetting: currentKeepUnlockedSetting)

		try viewModel.setKeepUnlockedSetting(to: .oneMinute)

		let expectedAutoLockItems: [AutoLockItem] = [
			.init(timeout: .off, selected: false),
			.init(timeout: .oneMinute, selected: true),
			.init(timeout: .twoMinutes, selected: false),
			.init(timeout: .fiveMinutes, selected: false),
			.init(timeout: .tenMinutes, selected: false),
			.init(timeout: .fifteenMinutes, selected: false),
			.init(timeout: .thirtyMinutes, selected: false),
			.init(timeout: .oneHour, selected: false),
			.init(timeout: .never, selected: false)
		]
		XCTAssertEqual(expectedAutoLockItems, viewModel.items)
		XCTAssertEqual(.oneMinute, currentKeepUnlockedSetting.value)
		XCTAssertEqual(1, vaultAutoLockingSettingsMock.setKeepUnlockedSettingForVaultUIDCallsCount)
		let receivedArguments = vaultAutoLockingSettingsMock.setKeepUnlockedSettingForVaultUIDReceivedArguments
		XCTAssertEqual(vaultUID, receivedArguments?.vaultUID)
		XCTAssertEqual(KeepUnlockedSetting.oneMinute, receivedArguments?.timeout)
		XCTAssertFalse(masterkeyCacheManagerMock.removeCachedMasterkeyForVaultUIDCalled)
	}

	func testSetKeepUnlockedSettingOff() throws {
		let currentKeepUnlockedSetting = Bindable(KeepUnlockedSetting.oneMinute)
		let viewModel = createViewModel(currentKeepUnlockedSetting: currentKeepUnlockedSetting)

		try viewModel.setKeepUnlockedSetting(to: .off)

		let expectedAutoLockItems: [AutoLockItem] = [
			.init(timeout: .off, selected: true),
			.init(timeout: .oneMinute, selected: false),
			.init(timeout: .twoMinutes, selected: false),
			.init(timeout: .fiveMinutes, selected: false),
			.init(timeout: .tenMinutes, selected: false),
			.init(timeout: .fifteenMinutes, selected: false),
			.init(timeout: .thirtyMinutes, selected: false),
			.init(timeout: .oneHour, selected: false),
			.init(timeout: .never, selected: false)
		]
		XCTAssertEqual(expectedAutoLockItems, viewModel.items)
		XCTAssertEqual(.off, currentKeepUnlockedSetting.value)
		XCTAssertEqual(1, vaultAutoLockingSettingsMock.setKeepUnlockedSettingForVaultUIDCallsCount)
		let receivedArguments = vaultAutoLockingSettingsMock.setKeepUnlockedSettingForVaultUIDReceivedArguments
		XCTAssertEqual(vaultUID, receivedArguments?.vaultUID)
		XCTAssertEqual(KeepUnlockedSetting.off, receivedArguments?.timeout)

		XCTAssertEqual([vaultUID], masterkeyCacheManagerMock.removeCachedMasterkeyForVaultUIDReceivedInvocations)
	}

	private func createViewModel(currentKeepUnlockedSetting: Bindable<KeepUnlockedSetting>) -> VaultKeepUnlockedViewModel {
		return VaultKeepUnlockedViewModel(currentKeepUnlockedSetting: currentKeepUnlockedSetting, vaultUID: vaultUID, vaultAutoLockSettings: vaultAutoLockingSettingsMock, masterkeyCacheManager: masterkeyCacheManagerMock)
	}
}
