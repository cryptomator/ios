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
	let vaultUID = "VaultUID-12345"

	override func setUpWithError() throws {
		vaultAutoLockingSettingsMock = VaultAutoLockingSettingsMock()
	}

	func testDefaultConfiguration() {
		let currentAutoLockTimeout = Bindable(AutoLockTimeout.twoMinutes)
		let viewModel = VaultKeepUnlockedViewModel(currentAutoLockTimeout: currentAutoLockTimeout, vaultUID: vaultUID, vaultAutoLockSettings: vaultAutoLockingSettingsMock)
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
		XCTAssertEqual(.twoMinutes, currentAutoLockTimeout.value)
		XCTAssertEqual(LocalizedString.getValue("vaultDetail.keepUnlocked.title"), viewModel.title)
	}

	func testSetAutoLockTimeout() throws {
		let currentAutoLockTimeout = Bindable(AutoLockTimeout.twoMinutes)
		let viewModel = VaultKeepUnlockedViewModel(currentAutoLockTimeout: currentAutoLockTimeout, vaultUID: vaultUID, vaultAutoLockSettings: vaultAutoLockingSettingsMock)

		try viewModel.setAutoLockTimeout(to: .oneMinute)

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
		XCTAssertEqual(.oneMinute, currentAutoLockTimeout.value)
		XCTAssertEqual(1, vaultAutoLockingSettingsMock.setAutoLockTimeoutForVaultUIDCallsCount)
		let receivedArguments = vaultAutoLockingSettingsMock.setAutoLockTimeoutForVaultUIDReceivedArguments
		XCTAssertEqual(vaultUID, receivedArguments?.vaultUID)
		XCTAssertEqual(AutoLockTimeout.oneMinute, receivedArguments?.timeout)
	}

	func testSetAutoLockTimeoutForAlreadySelectedItem() throws {
		let currentAutoLockTimeout = Bindable(AutoLockTimeout.oneMinute)
		let viewModel = VaultKeepUnlockedViewModel(currentAutoLockTimeout: currentAutoLockTimeout, vaultUID: vaultUID, vaultAutoLockSettings: vaultAutoLockingSettingsMock)

		try viewModel.setAutoLockTimeout(to: .oneMinute)

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
		XCTAssertEqual(.oneMinute, currentAutoLockTimeout.value)
		XCTAssertEqual(1, vaultAutoLockingSettingsMock.setAutoLockTimeoutForVaultUIDCallsCount)
		let receivedArguments = vaultAutoLockingSettingsMock.setAutoLockTimeoutForVaultUIDReceivedArguments
		XCTAssertEqual(vaultUID, receivedArguments?.vaultUID)
		XCTAssertEqual(AutoLockTimeout.oneMinute, receivedArguments?.timeout)
	}
}
