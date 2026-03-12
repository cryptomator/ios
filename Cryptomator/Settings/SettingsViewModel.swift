//
//  SettingsViewModel.swift
//  Cryptomator
//
//  Created by Tobias Hagemann on 04.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Combine
import CryptomatorCommonCore
import CryptomatorFileProvider
import Dependencies
import Foundation
import Promises
import StoreKit

enum SettingsButtonAction: String {
	case showAbout
	case sendLogFile
	case clearCache
	case showTrustedHubHosts
	case showCloudServices
	case showContact
	case showRateApp
	case showShortcutsGuide
	case showUnlockFullVersion
	case showUpgradeToLifetime
	case showManageSubscriptions
	case restorePurchase
}

enum SettingsSection: Int {
	case unlockFullVersionSection = 0
	case cloudServiceSection
	case cacheSection
	case hubSection
	case aboutSection
	case debugSection
	case miscSection
}

class SettingsViewModel: TableViewModel<SettingsSection> {
	override var title: String? {
		return LocalizedString.getValue("settings.title")
	}

	override var sections: [Section<SettingsSection>] {
		return _sections
	}

	override func getFooterTitle(for section: Int) -> String? {
		guard sections[section].id == .aboutSection, hasFullVersion else { return nil }
		return LocalizedString.getValue("settings.aboutCryptomator.hasFullVersion.footer")
	}

	var showDebugModeWarning: AnyPublisher<Void, Never> {
		return showDebugModeWarningPublisher.eraseToAnyPublisher()
	}

	private var hasFullVersion: Bool {
		cryptomatorSettings.hasRunningSubscription || cryptomatorSettings.fullVersionUnlocked
	}

	private var _sections: [Section<SettingsSection>] {
		var sections: [Section<SettingsSection>] = []
		if !hasFullVersion {
			sections.append(Section(id: .unlockFullVersionSection, elements: [unlockFullVersionCellViewModel]))
		}
		sections.append(contentsOf: [
			Section(id: .cloudServiceSection, elements: [
				ButtonCellViewModel.createDisclosureButton(action: SettingsButtonAction.showCloudServices, title: LocalizedString.getValue("settings.cloudServices"))
			]),
			Section(id: .cacheSection, elements: [
				cacheSizeCellViewModel,
				clearCacheButtonCellViewModel
			]),
			Section(id: .hubSection, elements: [
				ButtonCellViewModel.createDisclosureButton(action: SettingsButtonAction.showTrustedHubHosts, title: LocalizedString.getValue("settings.hub.trustedHosts"))
			]),
			Section(id: .aboutSection, elements: aboutSectionElements),
			Section(id: .debugSection, elements: [
				debugModeViewModel,
				ButtonCellViewModel<SettingsButtonAction>(action: .sendLogFile, title: LocalizedString.getValue("settings.sendLogFile"))
			]),
			Section(id: .miscSection, elements: [
				ButtonCellViewModel(action: SettingsButtonAction.showShortcutsGuide, title: LocalizedString.getValue("settings.shortcutsGuide")),
				ButtonCellViewModel(action: SettingsButtonAction.showContact, title: LocalizedString.getValue("settings.contact")),
				ButtonCellViewModel(action: SettingsButtonAction.showRateApp, title: LocalizedString.getValue("settings.rateApp"))
			])
		])
		return sections
	}

	private var aboutSectionElements: [TableViewCellViewModel] {
		var elements: [TableViewCellViewModel] = [
			ButtonCellViewModel.createDisclosureButton(action: SettingsButtonAction.showAbout, title: LocalizedString.getValue("settings.aboutCryptomator"))
		]
		if cryptomatorSettings.hasRunningSubscription {
			elements.append(ButtonCellViewModel.createDisclosureButton(action: SettingsButtonAction.showManageSubscriptions, title: LocalizedString.getValue("settings.manageSubscriptions")))
			if !cryptomatorSettings.fullVersionUnlocked {
				elements.append(ButtonCellViewModel.createDisclosureButton(action: SettingsButtonAction.showUpgradeToLifetime, title: LocalizedString.getValue("settings.upgradeToLifetime")))
			}
		}
		return elements
	}

	private var unlockFullVersionCellViewModel: ButtonCellViewModel<SettingsButtonAction> {
		let detailTitle: String
		if let trialExpirationDate = cryptomatorSettings.trialExpirationDate, trialExpirationDate > Date() {
			let formatter = DateFormatter()
			formatter.dateStyle = .short
			detailTitle = String(format: LocalizedString.getValue("settings.unlockFullVersion.trialExpirationDate"), formatter.string(from: trialExpirationDate))
		} else {
			detailTitle = LocalizedString.getValue("settings.unlockFullVersion.detail")
		}
		let image = UIImage(systemName: "checkmark.seal.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 22))
		return ButtonCellViewModel.createDisclosureButton(action: .showUnlockFullVersion, title: LocalizedString.getValue("settings.unlockFullVersion"), detailTitle: detailTitle, image: image, cellStyle: .subtitle)
	}

	private let cacheSizeCellViewModel = LoadingWithLabelCellViewModel(title: LocalizedString.getValue("settings.cacheSize"))
	private let clearCacheButtonCellViewModel = ButtonCellViewModel<SettingsButtonAction>(action: .clearCache, title: LocalizedString.getValue("settings.clearCache"), isEnabled: false)
	private var cryptomatorSettings: CryptomatorSettings

	private lazy var debugModeViewModel: SwitchCellViewModel = {
		let viewModel = SwitchCellViewModel(title: LocalizedString.getValue("settings.debugMode"), isOn: cryptomatorSettings.debugModeEnabled)
		bindDebugModeViewModel(viewModel)
		return viewModel
	}()

	@Dependency(\.fileProviderConnector) private var fileProviderConnector

	private var subscribers = Set<AnyCancellable>()
	private lazy var showDebugModeWarningPublisher = PassthroughSubject<Void, Never>()

	init(cryptomatorSettings: CryptomatorSettings = CryptomatorUserDefaults.shared) {
		self.cryptomatorSettings = cryptomatorSettings
	}

	func refreshCacheSize() -> Promise<Void> {
		var loading = true
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
			if loading {
				self.cacheSizeCellViewModel.isLoading.value = true
				self.clearCacheButtonCellViewModel.isEnabled.value = false
			}
		}
		let getXPCPromise: Promise<XPC<CacheManaging>> = fileProviderConnector.getXPC(serviceName: .cacheManaging, domain: nil)
		return getXPCPromise.then { xpc in
			xpc.proxy.getLocalCacheSizeInBytes()
		}.then { receivedCacheSizeInBytes -> Void in
			let totalCacheSizeInBytes = receivedCacheSizeInBytes?.intValue ?? 0
			loading = false
			self.cacheSizeCellViewModel.isLoading.value = false
			self.clearCacheButtonCellViewModel.isEnabled.value = totalCacheSizeInBytes > 0
			let formattedString = ByteCountFormatter().string(fromByteCount: Int64(totalCacheSizeInBytes))
			self.cacheSizeCellViewModel.detailTitle.value = formattedString
		}
	}

	func clearCache() -> Promise<Void> {
		let getXPCPromise: Promise<XPC<CacheManaging>> = fileProviderConnector.getXPC(serviceName: .cacheManaging, domain: nil)
		return getXPCPromise.then { xpc in
			xpc.proxy.clearCache()
		}.then {
			self.refreshCacheSize()
		}
	}

	func restorePurchase() -> Promise<RestoreTransactionsResult> {
		return StoreObserver.shared.restore()
	}

	func enableDebugMode() {
		setDebugMode(enabled: true)
	}

	func disableDebugMode() {
		setDebugMode(enabled: false)
		debugModeViewModel.isOn.value = false
	}

	private func setDebugMode(enabled: Bool) {
		cryptomatorSettings.debugModeEnabled = enabled
		LoggerSetup.setDynamicLogLevel(debugModeEnabled: enabled)
		notifyFileProviderAboutLogLevelUpdate()
	}

	private func bindDebugModeViewModel(_ viewModel: SwitchCellViewModel) {
		viewModel.isOnButtonPublisher.sink { [weak self] isOn in
			if isOn {
				self?.showDebugModeWarningPublisher.send()
			} else {
				self?.setDebugMode(enabled: false)
			}
		}.store(in: &subscribers)
	}

	private func notifyFileProviderAboutLogLevelUpdate() {
		let getXPCPromise: Promise<XPC<LogLevelUpdating>> = fileProviderConnector.getXPC(serviceName: .logLevelUpdating, domain: nil)
		getXPCPromise.then { xpc in
			xpc.proxy.logLevelUpdated()
		}.always {
			self.fileProviderConnector.invalidateXPC(getXPCPromise)
		}
	}
}
