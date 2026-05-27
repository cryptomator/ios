//
//  VaultKeepUnlockedViewModelTests.swift
//  CryptomatorTests
//
//  Created by Philipp Schmid on 04.01.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Dependencies
import XCTest
@testable import Cryptomator
@testable import CryptomatorCommonCore

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

	func testDefaultConfiguration() throws {
		try withDependencies {
			$0.fileProviderConnector = fileProviderConnectorMock
		} operation: {
			let currentKeepUnlockedDuration = Bindable<KeepUnlockedDuration>(.auto)
			let viewModel = self.createViewModel(currentKeepUnlockedDuration: currentKeepUnlockedDuration)
			self.assertSectionsAreCorrect(selectedKeepUnlockedDuration: .auto, viewModel: viewModel)
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
	}

	func testDefaultConfigurationNotDefaultKeepUnlockedDuration() throws {
		try withDependencies {
			$0.fileProviderConnector = fileProviderConnectorMock
		} operation: {
			let currentKeepUnlockedDuration = Bindable<KeepUnlockedDuration>(.fiveMinutes)
			let viewModel = self.createViewModel(currentKeepUnlockedDuration: currentKeepUnlockedDuration)
			self.assertSectionsAreCorrect(selectedKeepUnlockedDuration: .fiveMinutes, viewModel: viewModel)
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
	}

	func testSetKeepUnlockedDuration() {
		withDependencies {
			$0.fileProviderConnector = fileProviderConnectorMock
		} operation: {
			let expectation = XCTestExpectation()
			let currentKeepUnlockedDuration = Bindable<KeepUnlockedDuration>(KeepUnlockedDuration.fiveMinutes)
			let viewModel = self.createViewModel(currentKeepUnlockedDuration: currentKeepUnlockedDuration)

			viewModel.setKeepUnlockedDuration(to: .tenMinutes).catch { error in
				XCTFail("Promise rejected with error: \(error)")
			}.always {
				expectation.fulfill()
			}
			self.wait(for: [expectation], timeout: 5.0)
			self.assertSectionsAreCorrect(selectedKeepUnlockedDuration: .tenMinutes, viewModel: viewModel)

			XCTAssertEqual(.tenMinutes, currentKeepUnlockedDuration.value)
			self.assertVaultKeepUnlockedSettingsSetKeepUnlockedDurationCalled(with: .tenMinutes)
			XCTAssertFalse(self.masterkeyCacheManagerMock.removeCachedMasterkeyForVaultUIDCalled)
		}
	}

	func testSetKeepUnlockedDurationForUnlockedVault() {
		withDependencies {
			$0.fileProviderConnector = fileProviderConnectorMock
		} operation: {
			let expectation = XCTestExpectation()
			let currentKeepUnlockedDuration = Bindable<KeepUnlockedDuration>(.auto)
			let viewModel = self.createViewModel(currentKeepUnlockedDuration: currentKeepUnlockedDuration)
			self.fileProviderConnectorMock.proxy = self.vaultLockingMock
			self.vaultLockingMock.unlockedVaults.append(NSFileProviderDomainIdentifier(self.vaultUID))

			viewModel.setKeepUnlockedDuration(to: .fiveMinutes).then {
				XCTFail("Promise fulfilled")
			}.catch { error in
				XCTAssertEqual(.vaultIsUnlocked, error as? VaultKeepUnlockedViewModelError)
			}.always {
				expectation.fulfill()
			}
			self.wait(for: [expectation], timeout: 5.0)
			self.assertFileProviderConnectorCalled()
			self.assertSectionsAreCorrect(selectedKeepUnlockedDuration: .auto, viewModel: viewModel)
			XCTAssertEqual(.auto, currentKeepUnlockedDuration.value)
			XCTAssertFalse(self.vaultKeepUnlockedSettingsMock.setKeepUnlockedDurationForVaultUIDCalled)
			XCTAssertFalse(self.masterkeyCacheManagerMock.removeCachedMasterkeyForVaultUIDCalled)
			XCTAssertEqual(1, self.fileProviderConnectorMock.xpcInvalidationCallCount)
		}
	}

	func testSetKeepUnlockedDurationForLockedVault() {
		withDependencies {
			$0.fileProviderConnector = fileProviderConnectorMock
		} operation: {
			let expectation = XCTestExpectation()
			let currentKeepUnlockedDuration = Bindable<KeepUnlockedDuration>(.auto)
			let viewModel = self.createViewModel(currentKeepUnlockedDuration: currentKeepUnlockedDuration)
			self.fileProviderConnectorMock.proxy = self.vaultLockingMock

			viewModel.setKeepUnlockedDuration(to: .fiveMinutes).catch { error in
				XCTFail("Promise rejected with error: \(error)")
			}.always {
				expectation.fulfill()
			}
			self.wait(for: [expectation], timeout: 5.0)
			self.assertFileProviderConnectorCalled()
			XCTAssertEqual(.fiveMinutes, currentKeepUnlockedDuration.value)
			self.assertVaultKeepUnlockedSettingsSetKeepUnlockedDurationCalled(with: .fiveMinutes)
			XCTAssertFalse(self.masterkeyCacheManagerMock.removeCachedMasterkeyForVaultUIDCalled)
			XCTAssertEqual(1, self.fileProviderConnectorMock.xpcInvalidationCallCount)
		}
	}

	func testSetKeepUnlockedDurationForUnlockedVaultNotAutoDuration() {
		withDependencies {
			$0.fileProviderConnector = fileProviderConnectorMock
		} operation: {
			let expectation = XCTestExpectation()
			let currentKeepUnlockedDuration = Bindable<KeepUnlockedDuration>(.fiveMinutes)
			let viewModel = self.createViewModel(currentKeepUnlockedDuration: currentKeepUnlockedDuration)
			self.fileProviderConnectorMock.proxy = self.vaultLockingMock
			self.vaultLockingMock.unlockedVaults.append(NSFileProviderDomainIdentifier(self.vaultUID))

			viewModel.setKeepUnlockedDuration(to: .tenMinutes).catch { error in
				XCTFail("Promise rejected with error: \(error)")
			}.always {
				expectation.fulfill()
			}
			self.wait(for: [expectation], timeout: 5.0)
			self.assertFileProviderConnectorNotCalled()
			self.assertSectionsAreCorrect(selectedKeepUnlockedDuration: .tenMinutes, viewModel: viewModel)
			XCTAssertEqual(.tenMinutes, currentKeepUnlockedDuration.value)
			self.assertVaultKeepUnlockedSettingsSetKeepUnlockedDurationCalled(with: .tenMinutes)
			XCTAssertFalse(self.masterkeyCacheManagerMock.removeCachedMasterkeyForVaultUIDCalled)
		}
	}

	func testSetKeepUnlockedDurationAlreadySelectedDuration() {
		withDependencies {
			$0.fileProviderConnector = fileProviderConnectorMock
		} operation: {
			let expectation = XCTestExpectation()
			let currentKeepUnlockedDuration = Bindable<KeepUnlockedDuration>(KeepUnlockedDuration.fiveMinutes)
			let viewModel = self.createViewModel(currentKeepUnlockedDuration: currentKeepUnlockedDuration)

			viewModel.setKeepUnlockedDuration(to: .fiveMinutes).catch { error in
				XCTFail("Promise rejected with error: \(error)")
			}.always {
				expectation.fulfill()
			}
			self.wait(for: [expectation], timeout: 5.0)
			self.assertSectionsAreCorrect(selectedKeepUnlockedDuration: .fiveMinutes, viewModel: viewModel)

			XCTAssertEqual(.fiveMinutes, currentKeepUnlockedDuration.value)
			self.assertVaultKeepUnlockedSettingsSetKeepUnlockedDurationCalled(with: .fiveMinutes)
			XCTAssertFalse(self.masterkeyCacheManagerMock.removeCachedMasterkeyForVaultUIDCalled)
		}
	}

	func testSetKeepUnlockedDurationToAuto() {
		withDependencies {
			$0.fileProviderConnector = fileProviderConnectorMock
		} operation: {
			let expectation = XCTestExpectation()
			let currentKeepUnlockedDuration = Bindable<KeepUnlockedDuration>(KeepUnlockedDuration.fiveMinutes)
			let viewModel = self.createViewModel(currentKeepUnlockedDuration: currentKeepUnlockedDuration)

			viewModel.setKeepUnlockedDuration(to: .auto).catch { error in
				XCTFail("Promise rejected with error: \(error)")
			}.always {
				expectation.fulfill()
			}
			self.wait(for: [expectation], timeout: 5.0)
			self.assertSectionsAreCorrect(selectedKeepUnlockedDuration: .auto, viewModel: viewModel)
			XCTAssertEqual([self.vaultUID], self.masterkeyCacheManagerMock.removeCachedMasterkeyForVaultUIDReceivedInvocations)
		}
	}

	func testGracefulLockVault() {
		withDependencies {
			$0.fileProviderConnector = fileProviderConnectorMock
		} operation: {
			let expectation = XCTestExpectation()

			let currentKeepUnlockedDuration = Bindable<KeepUnlockedDuration>(.auto)
			let viewModel = self.createViewModel(currentKeepUnlockedDuration: currentKeepUnlockedDuration)
			self.vaultInfo.vaultIsUnlocked.value = true
			self.fileProviderConnectorMock.proxy = self.vaultLockingMock

			viewModel.gracefulLockVault().catch { error in
				XCTFail("Promise rejected with error: \(error)")
			}.always {
				expectation.fulfill()
			}
			self.wait(for: [expectation], timeout: 5.0)
			XCTAssertFalse(self.vaultInfo.vaultIsUnlocked.value)
			self.assertFileProviderConnectorCalled()
			XCTAssertEqual([NSFileProviderDomainIdentifier(self.vaultUID)], self.vaultLockingMock.lockedVaults)
			XCTAssertEqual(1, self.fileProviderConnectorMock.xpcInvalidationCallCount)
		}
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
