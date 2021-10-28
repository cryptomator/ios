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
import Foundation
import Promises

enum SettingsButtonAction: String {
	case showAbout
	case sendLogFile
	case clearCache
	case showCloudServices
	case showContact
	case showRateApp
	case unknown
}

enum SettingsSection: Int {
	case cloudServiceSection = 0
	case cacheSection
	case aboutSection
	case debugSection
	case miscSection
}

class SettingsViewModel {
	var sections: [SettingsSection] = [.cloudServiceSection, .cacheSection, .aboutSection, .debugSection, .miscSection]
	lazy var cells: [SettingsSection: [TableViewCellViewModel]] = {
		[
			.cloudServiceSection: [
				ButtonCellViewModel.createDisclosureButton(action: SettingsButtonAction.showCloudServices, title: LocalizedString.getValue("settings.cloudServices"))
			],
			.cacheSection: [
				cacheSizeCellViewModel,
				clearCacheButtonCellViewModel
			],
			.aboutSection: [
				ButtonCellViewModel.createDisclosureButton(action: SettingsButtonAction.showAbout, title: LocalizedString.getValue("settings.aboutCryptomator"))
			],
			.debugSection: [
				debugModeViewModel,
				ButtonCellViewModel<SettingsButtonAction>(action: .sendLogFile, title: LocalizedString.getValue("settings.sendLogFile"))
			],
			.miscSection: [
				ButtonCellViewModel(action: SettingsButtonAction.showContact, title: LocalizedString.getValue("settings.contact")),
				ButtonCellViewModel(action: SettingsButtonAction.showRateApp, title: LocalizedString.getValue("settings.rateApp"))
			]
		]
	}()

	private let cacheManager: FileProviderCacheManager
	private let cacheSizeCellViewModel = LoadingWithLabelCellViewModel(title: LocalizedString.getValue("settings.cacheSize"))
	private let clearCacheButtonCellViewModel = ButtonCellViewModel<SettingsButtonAction>(action: .clearCache, title: LocalizedString.getValue("settings.clearCache"), isEnabled: false)

	private var cryptomatorSettings: CryptomatorSettings
	private lazy var debugModeViewModel: SwitchCellViewModel = {
		let viewModel = SwitchCellViewModel(title: LocalizedString.getValue("settings.debugMode"), isOn: cryptomatorSettings.debugModeEnabled)
		bindDebugModeViewModel(viewModel)
		return viewModel
	}()

	private let fileProviderConnector: FileProviderConnector
	private var subscribers = Set<AnyCancellable>()

	init(cacheManager: FileProviderCacheManager = FileProviderCacheManager(), cryptomatorSetttings: CryptomatorSettings = CryptomatorUserDefaults.shared, fileProviderConnector: FileProviderConnector = FileProviderXPCConnector.shared) {
		self.cacheManager = cacheManager
		self.cryptomatorSettings = cryptomatorSetttings
		self.fileProviderConnector = fileProviderConnector
	}

	func buttonAction(for indexPath: IndexPath) -> SettingsButtonAction {
		let section = sections[indexPath.section]
		guard let cell = cells[section]?[indexPath.row] as? ButtonCellViewModel<SettingsButtonAction> else {
			return .unknown
		}
		return cell.action
	}

	func refreshCacheSize() -> Promise<Void> {
		var loading = true
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
			if loading {
				self.cacheSizeCellViewModel.isLoading.value = true
				self.clearCacheButtonCellViewModel.isEnabled.value = false
			}
		}
		return cacheManager.getTotalLocalCacheSizeInBytes().then { totalCacheSizeInBytes -> Void in
			loading = false
			self.cacheSizeCellViewModel.isLoading.value = false
			self.clearCacheButtonCellViewModel.isEnabled.value = totalCacheSizeInBytes > 0
			let formattedString = ByteCountFormatter().string(fromByteCount: Int64(totalCacheSizeInBytes))
			self.cacheSizeCellViewModel.detailTitle.value = formattedString
		}
	}

	func clearCache() -> Promise<Void> {
		return cacheManager.clearCache().then {
			self.refreshCacheSize()
		}
	}

	private func bindDebugModeViewModel(_ viewModel: SwitchCellViewModel) {
		viewModel.isOnButtonPublisher.sink { [weak self] isOn in
			self?.cryptomatorSettings.debugModeEnabled = isOn
			LoggerSetup.setDynamicLogLevel(debugModeEnabled: isOn)
			self?.notifyFileProviderAboutLogLevelUpdate()
		}.store(in: &subscribers)
	}

	private func notifyFileProviderAboutLogLevelUpdate() {
		let getProxyPromise: Promise<LogLevelUpdating> = fileProviderConnector.getProxy(serviceName: LogLevelUpdatingService.name, domain: nil)
		getProxyPromise.then { proxy in
			proxy.logLevelUpdated()
		}
	}
}
