//
//  VaultKeepUnlockedViewModelTests.swift
//  CryptomatorTests
//
//  Created by Philipp Schmid on 04.01.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import XCTest
@testable import Cryptomator
@testable import CryptomatorCommonCore
@testable import Dependencies

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
		DependencyValues.mockDependency(\.fileProviderConnector, with: fileProviderConnectorMock)
	}

	func testDefaultConfiguration() throws {
		let currentKeepUnlockedDuration = Bindable<KeepUnlockedDuration>(.auto)
		let viewModel = createViewModel(currentKeepUnlockedDuration: currentKeepUnlockedDuration)
		assertSectionsAreCorrect(selectedKeepUnlockedDuration: .auto, viewModel: viewModel)
		XCTAssertEqual(.auto, currentKeepUnlockedDuration.value)
		XCTAssertEqual(LocalizedString.getValue("vaultDetail.keepUnlocked.title"), viewModel.title)

		let mainFooterViewModel = try XCTUnwrap(viewModel.getFooterViewModel(forSection: 0))
		guard let attributedTextViewModel = mainFooterViewModel as? BindableAttributedTextHeaderFooterViewModel else {
			XCTFail("mainFooterViewModel has unexpected type")
			return
		}

		let footerInfoText = LocalizedString.getValue("keepUnlocked.footer.auto")
		let learnMoreText = LocalizedString.getValue("common.footer.learnMore")
		let expectedFooterText = "\(footerInfoText) \(learnMoreText)"
		XCTAssertEqual(expectedFooterText, attributedTextViewModel.attributedText.value.string)
	}

	func testDefaultConfigurationNotDefaultKeepUnlockedDuration() throws {
		let currentKeepUnlockedDuration = Bindable<KeepUnlockedDuration>(.fiveMinutes)
		let viewModel = createViewModel(currentKeepUnlockedDuration: currentKeepUnlockedDuration)
		assertSectionsAreCorrect(selectedKeepUnlockedDuration: .fiveMinutes, viewModel: viewModel)
		XCTAssertEqual(.fiveMinutes, currentKeepUnlockedDuration.value)
		XCTAssertEqual(LocalizedString.getValue("vaultDetail.keepUnlocked.title"), viewModel.title)

		let mainFooterViewModel = try XCTUnwrap(viewModel.getFooterViewModel(forSection: 0))
		guard let attributedTextViewModel = mainFooterViewModel as? BindableAttributedTextHeaderFooterViewModel else {
			XCTFail("mainFooterViewModel has unexpected type")
			return
		}

		let footerInfoText = LocalizedString.getValue("keepUnlocked.footer.on")
		let learnMoreText = LocalizedString.getValue("common.footer.learnMore")
		let expectedFooterText = "\(footerInfoText) \(learnMoreText)"
		XCTAssertEqual(expectedFooterText, attributedTextViewModel.attributedText.value.string)
	}

	func testSetKeepUnlockedDuration() throws {
		let expectation = XCTestExpectation()
		let currentKeepUnlockedDuration = Bindable<KeepUnlockedDuration>(KeepUnlockedDuration.fiveMinutes)
		let viewModel = createViewModel(currentKeepUnlockedDuration: currentKeepUnlockedDuration)

		viewModel.setKeepUnlockedDuration(to: .tenMinutes).catch { error in
			XCTFail("Promise rejected with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
		assertSectionsAreCorrect(selectedKeepUnlockedDuration: .tenMinutes, viewModel: viewModel)

		XCTAssertEqual(.tenMinutes, currentKeepUnlockedDuration.value)
		assertVaultKeepUnlockedSettingsSetKeepUnlockedDurationCalled(with: .tenMinutes)
		XCTAssertFalse(masterkeyCacheManagerMock.removeCachedMasterkeyForVaultUIDCalled)
	}

	func testSetKeepUnlockedDurationForUnlockedVault() throws {
		let expectation = XCTestExpectation()
		let currentKeepUnlockedDuration = Bindable<KeepUnlockedDuration>(.auto)
		let viewModel = createViewModel(currentKeepUnlockedDuration: currentKeepUnlockedDuration)
		fileProviderConnectorMock.proxy = vaultLockingMock
		vaultLockingMock.unlockedVaults.append(NSFileProviderDomainIdentifier(vaultUID))

		viewModel.setKeepUnlockedDuration(to: .fiveMinutes).then {
			XCTFail("Promise fulfilled")
		}.catch { error in
			XCTAssertEqual(.vaultIsUnlocked, error as? VaultKeepUnlockedViewModelError)
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
		assertFileProviderConnectorCalled()
		assertSectionsAreCorrect(selectedKeepUnlockedDuration: .auto, viewModel: viewModel)
		XCTAssertEqual(.auto, currentKeepUnlockedDuration.value)
		XCTAssertFalse(vaultKeepUnlockedSettingsMock.setKeepUnlockedDurationForVaultUIDCalled)
		XCTAssertFalse(masterkeyCacheManagerMock.removeCachedMasterkeyForVaultUIDCalled)
		XCTAssertEqual(1, fileProviderConnectorMock.xpcInvalidationCallCount)
	}

	func testSetKeepUnlockedDurationForLockedVault() throws {
		let expectation = XCTestExpectation()
		let currentKeepUnlockedDuration = Bindable<KeepUnlockedDuration>(.auto)
		let viewModel = createViewModel(currentKeepUnlockedDuration: currentKeepUnlockedDuration)
		fileProviderConnectorMock.proxy = vaultLockingMock

		viewModel.setKeepUnlockedDuration(to: .fiveMinutes).catch { error in
			XCTFail("Promise rejected with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
		assertFileProviderConnectorCalled()
		XCTAssertEqual(.fiveMinutes, currentKeepUnlockedDuration.value)
		assertVaultKeepUnlockedSettingsSetKeepUnlockedDurationCalled(with: .fiveMinutes)
		XCTAssertFalse(masterkeyCacheManagerMock.removeCachedMasterkeyForVaultUIDCalled)
		XCTAssertEqual(1, fileProviderConnectorMock.xpcInvalidationCallCount)
	}

	func testSetKeepUnlockedDurationForUnlockedVaultNotAutoDuration() throws {
		let expectation = XCTestExpectation()
		let currentKeepUnlockedDuration = Bindable<KeepUnlockedDuration>(.fiveMinutes)
		let viewModel = createViewModel(currentKeepUnlockedDuration: currentKeepUnlockedDuration)
		fileProviderConnectorMock.proxy = vaultLockingMock
		vaultLockingMock.unlockedVaults.append(NSFileProviderDomainIdentifier(vaultUID))

		viewModel.setKeepUnlockedDuration(to: .tenMinutes).catch { error in
			XCTFail("Promise rejected with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
		assertFileProviderConnectorNotCalled()
		assertSectionsAreCorrect(selectedKeepUnlockedDuration: .tenMinutes, viewModel: viewModel)
		XCTAssertEqual(.tenMinutes, currentKeepUnlockedDuration.value)
		assertVaultKeepUnlockedSettingsSetKeepUnlockedDurationCalled(with: .tenMinutes)
		XCTAssertFalse(masterkeyCacheManagerMock.removeCachedMasterkeyForVaultUIDCalled)
	}

	func testSetKeepUnlockedDurationAlreadySelectedDuration() throws {
		let expectation = XCTestExpectation()
		let currentKeepUnlockedDuration = Bindable<KeepUnlockedDuration>(KeepUnlockedDuration.fiveMinutes)
		let viewModel = createViewModel(currentKeepUnlockedDuration: currentKeepUnlockedDuration)

		viewModel.setKeepUnlockedDuration(to: .fiveMinutes).catch { error in
			XCTFail("Promise rejected with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
		assertSectionsAreCorrect(selectedKeepUnlockedDuration: .fiveMinutes, viewModel: viewModel)

		XCTAssertEqual(.fiveMinutes, currentKeepUnlockedDuration.value)
		assertVaultKeepUnlockedSettingsSetKeepUnlockedDurationCalled(with: .fiveMinutes)
		XCTAssertFalse(masterkeyCacheManagerMock.removeCachedMasterkeyForVaultUIDCalled)
	}

	func testSetKeepUnlockedDurationToAuto() {
		let expectation = XCTestExpectation()
		let currentKeepUnlockedDuration = Bindable<KeepUnlockedDuration>(KeepUnlockedDuration.fiveMinutes)
		let viewModel = createViewModel(currentKeepUnlockedDuration: currentKeepUnlockedDuration)

		viewModel.setKeepUnlockedDuration(to: .auto).catch { error in
			XCTFail("Promise rejected with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
		assertSectionsAreCorrect(selectedKeepUnlockedDuration: .auto, viewModel: viewModel)
		XCTAssertEqual([vaultUID], masterkeyCacheManagerMock.removeCachedMasterkeyForVaultUIDReceivedInvocations)
	}

	func testGracefulLockVault() throws {
		let expectation = XCTestExpectation()

		let currentKeepUnlockedDuration = Bindable<KeepUnlockedDuration>(.auto)
		let viewModel = createViewModel(currentKeepUnlockedDuration: currentKeepUnlockedDuration)
		vaultInfo.vaultIsUnlocked.value = true
		fileProviderConnectorMock.proxy = vaultLockingMock

		viewModel.gracefulLockVault().catch { error in
			XCTFail("Promise rejected with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
		XCTAssertFalse(vaultInfo.vaultIsUnlocked.value)
		assertFileProviderConnectorCalled()
		XCTAssertEqual([NSFileProviderDomainIdentifier(vaultUID)], vaultLockingMock.lockedVaults)
		XCTAssertEqual(1, fileProviderConnectorMock.xpcInvalidationCallCount)
	}

	private func createViewModel(currentKeepUnlockedDuration: Bindable<KeepUnlockedDuration>) -> VaultKeepUnlockedViewModel {
		return VaultKeepUnlockedViewModel(currentKeepUnlockedDuration: currentKeepUnlockedDuration,
		                                  vaultInfo: vaultInfo,
		                                  vaultKeepUnlockedSettings: vaultKeepUnlockedSettingsMock,
		                                  masterkeyCacheManager: masterkeyCacheManagerMock)
	}

	private func assertSectionsAreCorrect(selectedKeepUnlockedDuration: KeepUnlockedDuration, viewModel: VaultKeepUnlockedViewModel) {
		let expectedKeepUnlockedItems: [KeepUnlockedDurationItem] = [
			.init(duration: .auto, isSelected: false),
			.init(duration: .fiveMinutes, isSelected: false),
			.init(duration: .tenMinutes, isSelected: false),
			.init(duration: .thirtyMinutes, isSelected: false),
			.init(duration: .oneHour, isSelected: false),
			.init(duration: .indefinite, isSelected: false)
		]
		for expectedKeepUnlockedItem in expectedKeepUnlockedItems {
			expectedKeepUnlockedItem.isSelected.value = expectedKeepUnlockedItem.duration == selectedKeepUnlockedDuration
		}
		let expectedSections: [Section<VaultKeepUnlockedSection>] = [
			Section(id: .main, elements: viewModel.keepUnlockedItems)
		]

		XCTAssertEqual(expectedSections, viewModel.sections)
		XCTAssertEqual(expectedKeepUnlockedItems.hashValue, viewModel.keepUnlockedItems.hashValue)
	}

	private func assertFileProviderConnectorCalled() {
		XCTAssertEqual(vaultUID, fileProviderConnectorMock.passedDomainIdentifier?.rawValue)
		XCTAssertEqual(.vaultLocking, fileProviderConnectorMock.passedServiceName)
	}

	private func assertFileProviderConnectorNotCalled() {
		XCTAssertNil(fileProviderConnectorMock.passedServiceName)
		XCTAssertNil(fileProviderConnectorMock.passedDomainIdentifier)
		XCTAssertNil(fileProviderConnectorMock.passedDomain)
	}

	private func assertVaultKeepUnlockedSettingsSetKeepUnlockedDurationCalled(with duration: KeepUnlockedDuration) {
		XCTAssertEqual(1, vaultKeepUnlockedSettingsMock.setKeepUnlockedDurationForVaultUIDCallsCount)
		let receivedArguments = vaultKeepUnlockedSettingsMock.setKeepUnlockedDurationForVaultUIDReceivedArguments
		XCTAssertEqual(vaultUID, receivedArguments?.vaultUID)
		XCTAssertEqual(duration, receivedArguments?.duration)
	}
}
