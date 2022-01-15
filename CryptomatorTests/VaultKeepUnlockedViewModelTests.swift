//
//  VaultKeepUnlockedViewModelTests.swift
//  CryptomatorTests
//
//  Created by Philipp Schmid on 04.01.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import XCTest
@testable import Cryptomator

class VaultKeepUnlockedViewModelTests: XCTestCase {
	var vaultKeepUnlockedSettingsMock: VaultKeepUnlockedSettingsMock!
	var masterkeyCacheManagerMock: MasterkeyCacheManagerMock!
	var fileProviderConnectorMock: FileProviderConnectorMock!
	var vaultLockingMock: VaultLockingMock!
	let vaultUID = "VaultUID-12345"
	let cloudProviderAccount = CloudProviderAccount(accountUID: "AccountUID", cloudProviderType: .dropbox)
	lazy var vaultAccount = VaultAccount(vaultUID: vaultUID, delegateAccountUID: "AccountUID", vaultPath: CloudPath("/Vault"), vaultName: "Test Vault")
	lazy var vaultInfo = VaultInfo(vaultAccount: vaultAccount, cloudProviderAccount: cloudProviderAccount, vaultListPosition: VaultListPosition(position: 0, vaultUID: vaultUID))

	override func setUpWithError() throws {
		vaultKeepUnlockedSettingsMock = VaultKeepUnlockedSettingsMock()
		masterkeyCacheManagerMock = MasterkeyCacheManagerMock()
		fileProviderConnectorMock = FileProviderConnectorMock()
		vaultLockingMock = VaultLockingMock()
	}

	func testDefaultConfigurationKeepUnlockedDisabled() throws {
		let currentKeepUnlockedDuration = Bindable<KeepUnlockedDuration?>(nil)
		let viewModel = createViewModel(currentKeepUnlockedDuration: currentKeepUnlockedDuration)
		assertSectionsForDisabledKeepUnlocked(viewModel: viewModel)
		XCTAssertNil(currentKeepUnlockedDuration.value)
		XCTAssertEqual(LocalizedString.getValue("vaultDetail.keepUnlocked.title"), viewModel.title)

		let mainFooterViewModel = try XCTUnwrap(viewModel.getFooterViewModel(for: 0))
		guard let attributedTextViewModel = mainFooterViewModel as? AttributedTextHeaderFooterViewModel else {
			XCTFail("mainFooterViewModel has unexpected type")
			return
		}

		let footerInfoText = LocalizedString.getValue("keepUnlocked.footer.main.off")
		let learnMoreText = LocalizedString.getValue("common.footer.learnMore")
		let expectedFooterText = "\(footerInfoText) \(learnMoreText)"
		XCTAssertEqual(expectedFooterText, attributedTextViewModel.attributedText.string)

		XCTAssertFalse(viewModel.enableKeepUnlockedViewModel.isOn.value)
	}

	func testDefaultConfigurationKeepUnlockedEnabled() throws {
		let currentKeepUnlockedDuration = Bindable<KeepUnlockedDuration?>(.oneMinute)
		let viewModel = createViewModel(currentKeepUnlockedDuration: currentKeepUnlockedDuration)
		assertSectionsForEnabledKeepUnlocked(selectedKeepUnlockedDuration: .oneMinute, viewModel: viewModel)
		XCTAssertEqual(.oneMinute, currentKeepUnlockedDuration.value)
		XCTAssertEqual(LocalizedString.getValue("vaultDetail.keepUnlocked.title"), viewModel.title)

		let mainFooterViewModel = try XCTUnwrap(viewModel.getFooterViewModel(for: 0))
		guard let attributedTextViewModel = mainFooterViewModel as? AttributedTextHeaderFooterViewModel else {
			XCTFail("mainFooterViewModel has unexpected type")
			return
		}

		let footerInfoText = LocalizedString.getValue("keepUnlocked.footer.main.on")
		let learnMoreText = LocalizedString.getValue("common.footer.learnMore")
		let expectedFooterText = "\(footerInfoText) \(learnMoreText)"
		XCTAssertEqual(expectedFooterText, attributedTextViewModel.attributedText.string)

		XCTAssert(viewModel.enableKeepUnlockedViewModel.isOn.value)
	}

	func testEnableKeepUnlocked() throws {
		let expecation = XCTestExpectation()
		let defaultKeepUnlockedDuration = vaultKeepUnlockedSettingsMock.defaultKeepUnlockedDuration
		let currentKeepUnlockedDuration = Bindable<KeepUnlockedDuration?>(nil)
		let viewModel = createViewModel(currentKeepUnlockedDuration: currentKeepUnlockedDuration)
		fileProviderConnectorMock.proxy = vaultLockingMock

		viewModel.enableKeepUnlocked().catch { error in
			XCTFail("Promise rejected with error: \(error)")
		}.always {
			expecation.fulfill()
		}
		wait(for: [expecation], timeout: 1.0)
		assertFileProviderConnectorCalled()
		assertSectionsForEnabledKeepUnlocked(selectedKeepUnlockedDuration: defaultKeepUnlockedDuration, viewModel: viewModel)
		XCTAssertEqual(defaultKeepUnlockedDuration, currentKeepUnlockedDuration.value)
		XCTAssertEqual(1, vaultKeepUnlockedSettingsMock.setKeepUnlockedDurationForVaultUIDCallsCount)
		let receivedArguments = vaultKeepUnlockedSettingsMock.setKeepUnlockedDurationForVaultUIDReceivedArguments
		XCTAssertEqual(vaultUID, receivedArguments?.vaultUID)
		XCTAssertEqual(defaultKeepUnlockedDuration, receivedArguments?.duration)
		XCTAssertFalse(masterkeyCacheManagerMock.removeCachedMasterkeyForVaultUIDCalled)
	}

	func testEnableKeepUnlockedForUnlockedVault() throws {
		let expecation = XCTestExpectation()
		let currentKeepUnlockedDuration = Bindable<KeepUnlockedDuration?>(nil)
		let viewModel = createViewModel(currentKeepUnlockedDuration: currentKeepUnlockedDuration)
		fileProviderConnectorMock.proxy = vaultLockingMock
		vaultLockingMock.unlockedVaults.append(NSFileProviderDomainIdentifier(vaultUID))

		viewModel.enableKeepUnlocked().then {
			XCTFail("Promise fulfilled")
		}.catch { error in
			XCTAssertEqual(.vaultIsUnlocked, error as? VaultKeepUnlockedViewModelError)
		}.always {
			expecation.fulfill()
		}
		wait(for: [expecation], timeout: 1.0)
		assertFileProviderConnectorCalled()
		assertSectionsForDisabledKeepUnlocked(viewModel: viewModel)
		XCTAssertNil(currentKeepUnlockedDuration.value)
		XCTAssertFalse(vaultKeepUnlockedSettingsMock.setKeepUnlockedDurationForVaultUIDCalled)
		XCTAssertFalse(masterkeyCacheManagerMock.removeCachedMasterkeyForVaultUIDCalled)
	}

	func testEnableKeepUnlockedWithAlreadySetKeepUnlockedDuration() throws {
		let expecation = XCTestExpectation()
		let currentKeepUnlockedDuration = Bindable<KeepUnlockedDuration?>(.oneMinute)
		let viewModel = createViewModel(currentKeepUnlockedDuration: currentKeepUnlockedDuration)

		viewModel.enableKeepUnlocked().catch { error in
			XCTFail("Promise rejected with error: \(error)")
		}.always {
			expecation.fulfill()
		}
		wait(for: [expecation], timeout: 1.0)
		assertFileProviderConnectorNotCalled()
		assertSectionsForEnabledKeepUnlocked(selectedKeepUnlockedDuration: .oneMinute, viewModel: viewModel)
		XCTAssertEqual(.oneMinute, currentKeepUnlockedDuration.value)
		XCTAssertFalse(vaultKeepUnlockedSettingsMock.setKeepUnlockedDurationForVaultUIDCalled)
		XCTAssertFalse(masterkeyCacheManagerMock.removeCachedMasterkeyForVaultUIDCalled)
	}

	func testDisableKeepUnlocked() throws {
		let currentKeepUnlockedDuration = Bindable<KeepUnlockedDuration?>(.oneMinute)
		let viewModel = createViewModel(currentKeepUnlockedDuration: currentKeepUnlockedDuration)
		viewModel.enableKeepUnlockedViewModel.isOn.value = true

		try viewModel.disableKeepUnlocked()

		assertSectionsForDisabledKeepUnlocked(viewModel: viewModel)
		XCTAssertFalse(viewModel.enableKeepUnlockedViewModel.isOn.value)
		XCTAssertEqual([vaultUID], masterkeyCacheManagerMock.removeCachedMasterkeyForVaultUIDReceivedInvocations)
		XCTAssertEqual([vaultUID], vaultKeepUnlockedSettingsMock.removeKeepUnlockedDurationForVaultUIDReceivedInvocations)
	}

	func testSetKeepUnlockedDuration() throws {
		let currentKeepUnlockedDuration = Bindable<KeepUnlockedDuration?>(KeepUnlockedDuration.oneMinute)
		let viewModel = createViewModel(currentKeepUnlockedDuration: currentKeepUnlockedDuration)

		try viewModel.setKeepUnlockedDuration(to: .twoMinutes)
		assertSectionsForEnabledKeepUnlocked(selectedKeepUnlockedDuration: .twoMinutes, viewModel: viewModel)

		XCTAssertEqual(.twoMinutes, currentKeepUnlockedDuration.value)
		XCTAssertEqual(1, vaultKeepUnlockedSettingsMock.setKeepUnlockedDurationForVaultUIDCallsCount)
		let receivedArguments = vaultKeepUnlockedSettingsMock.setKeepUnlockedDurationForVaultUIDReceivedArguments
		XCTAssertEqual(vaultUID, receivedArguments?.vaultUID)
		XCTAssertEqual(KeepUnlockedDuration.twoMinutes, receivedArguments?.duration)
		XCTAssertFalse(masterkeyCacheManagerMock.removeCachedMasterkeyForVaultUIDCalled)
	}

	func testSetKeepUnlockedDurationAlreadySelectedDuration() throws {
		let currentKeepUnlockedDuration = Bindable<KeepUnlockedDuration?>(KeepUnlockedDuration.oneMinute)
		let viewModel = createViewModel(currentKeepUnlockedDuration: currentKeepUnlockedDuration)

		try viewModel.setKeepUnlockedDuration(to: .oneMinute)
		assertSectionsForEnabledKeepUnlocked(selectedKeepUnlockedDuration: .oneMinute, viewModel: viewModel)

		XCTAssertEqual(.oneMinute, currentKeepUnlockedDuration.value)
		XCTAssertEqual(1, vaultKeepUnlockedSettingsMock.setKeepUnlockedDurationForVaultUIDCallsCount)
		let receivedArguments = vaultKeepUnlockedSettingsMock.setKeepUnlockedDurationForVaultUIDReceivedArguments
		XCTAssertEqual(vaultUID, receivedArguments?.vaultUID)
		XCTAssertEqual(KeepUnlockedDuration.oneMinute, receivedArguments?.duration)
		XCTAssertFalse(masterkeyCacheManagerMock.removeCachedMasterkeyForVaultUIDCalled)
	}

	func testGracefulLockVault() throws {
		let expecation = XCTestExpectation()

		let currentKeepUnlockedDuration = Bindable<KeepUnlockedDuration?>(nil)
		let viewModel = createViewModel(currentKeepUnlockedDuration: currentKeepUnlockedDuration)
		viewModel.enableKeepUnlockedViewModel.isOn.value = true
		vaultInfo.vaultIsUnlocked.value = true
		fileProviderConnectorMock.proxy = vaultLockingMock

		viewModel.gracefulLockVault().catch { error in
			XCTFail("Promise rejected with error: \(error)")
		}.always {
			expecation.fulfill()
		}
		wait(for: [expecation], timeout: 1.0)
		XCTAssertFalse(vaultInfo.vaultIsUnlocked.value)
		XCTAssert(viewModel.enableKeepUnlockedViewModel.isOn.value)
		assertFileProviderConnectorCalled()
		XCTAssertEqual([NSFileProviderDomainIdentifier(vaultUID)], vaultLockingMock.lockedVaults)
	}

	private func createViewModel(currentKeepUnlockedDuration: Bindable<KeepUnlockedDuration?>) -> VaultKeepUnlockedViewModel {
		return VaultKeepUnlockedViewModel(currentKeepUnlockedDuration: currentKeepUnlockedDuration,
		                                  vaultInfo: vaultInfo,
		                                  vaultKeepUnlockedSettings: vaultKeepUnlockedSettingsMock,
		                                  masterkeyCacheManager: masterkeyCacheManagerMock,
		                                  fileProviderConnector: fileProviderConnectorMock)
	}

	private func assertSectionsForEnabledKeepUnlocked(selectedKeepUnlockedDuration: KeepUnlockedDuration, viewModel: VaultKeepUnlockedViewModel) {
		let expectedKeepUnlockedItems: [KeepUnlockedDurationItem] = [
			.init(duration: .oneMinute, isSelected: true),
			.init(duration: .twoMinutes, isSelected: false),
			.init(duration: .fiveMinutes, isSelected: false),
			.init(duration: .tenMinutes, isSelected: false),
			.init(duration: .fifteenMinutes, isSelected: false),
			.init(duration: .thirtyMinutes, isSelected: false),
			.init(duration: .oneHour, isSelected: false),
			.init(duration: .forever, isSelected: false)
		]
		expectedKeepUnlockedItems.forEach {
			$0.isSelected.value = $0.duration == selectedKeepUnlockedDuration
		}
		let expectedSections: [Section<VaultKeepUnlockedSection>] = [
			Section(id: .main(unlocked: true), elements: [viewModel.enableKeepUnlockedViewModel]),
			Section(id: .keepUnlockedDurations, elements: viewModel.keepUnlockedItems)
		]

		XCTAssertEqual(expectedSections, viewModel.sections)
		XCTAssertEqual(expectedKeepUnlockedItems.hashValue, viewModel.keepUnlockedItems.hashValue)
	}

	private func assertSectionsForDisabledKeepUnlocked(viewModel: VaultKeepUnlockedViewModel) {
		let expectedSections = [Section<VaultKeepUnlockedSection>(id: .main(unlocked: false), elements: [viewModel.enableKeepUnlockedViewModel])]
		XCTAssertEqual(expectedSections, viewModel.sections)
	}

	private func assertFileProviderConnectorCalled() {
		XCTAssertEqual(vaultUID, fileProviderConnectorMock.passedDomainIdentifier?.rawValue)
		XCTAssertEqual(VaultLockingService.name, fileProviderConnectorMock.passedServiceName)
	}

	private func assertFileProviderConnectorNotCalled() {
		XCTAssertNil(fileProviderConnectorMock.passedServiceName)
		XCTAssertNil(fileProviderConnectorMock.passedDomainIdentifier)
		XCTAssertNil(fileProviderConnectorMock.passedDomain)
	}
}
