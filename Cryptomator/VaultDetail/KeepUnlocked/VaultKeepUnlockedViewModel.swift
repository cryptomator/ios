//
//  VaultKeepUnlockedViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 30.12.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Combine
import CryptomatorCommonCore
import FileProvider
import Foundation
import Promises

protocol VaultKeepUnlockedViewModelType: TableViewModel<VaultKeepUnlockedSection> {
	var keepUnlockedIsEnabled: AnyPublisher<Bool, Never> { get }
	var sectionsPublisher: AnyPublisher<[Section<VaultKeepUnlockedSection>], Never> { get }
	func setKeepUnlockedDuration(to duration: KeepUnlockedDuration) throws
	func enableKeepUnlocked() -> Promise<Void>
	func disableKeepUnlocked() throws
	func gracefulLockVault() -> Promise<Void>
	func getFooterViewModel(for section: Int) -> HeaderFooterViewModel?
}

enum VaultKeepUnlockedSection: Hashable {
	case main(unlocked: Bool)
	case keepUnlockedDurations
}

enum VaultKeepUnlockedViewModelError: Error {
	case vaultIsUnlocked
}

class VaultKeepUnlockedViewModel: TableViewModel<VaultKeepUnlockedSection>, VaultKeepUnlockedViewModelType {
	override var title: String {
		return LocalizedString.getValue("vaultDetail.keepUnlocked.title")
	}

	override var sections: [Section<VaultKeepUnlockedSection>] {
		return _sections.value
	}

	var keepUnlockedIsEnabled: AnyPublisher<Bool, Never> {
		return enableKeepUnlockedViewModel.isOnButtonPublisher.eraseToAnyPublisher()
	}

	var sectionsPublisher: AnyPublisher<[Section<VaultKeepUnlockedSection>], Never> {
		return _sections.$value.eraseToAnyPublisher()
	}

	lazy var enableKeepUnlockedViewModel = SwitchCellViewModel(title: LocalizedString.getValue("vaultDetail.keepUnlocked.title"),
	                                                           isOn: currentKeepUnlockedDuration.value != nil)
	private lazy var keepUnlockedDurationSection = Section(id: VaultKeepUnlockedSection.keepUnlockedDurations, elements: keepUnlockedItems)
	private lazy var _sections: Bindable<[Section<VaultKeepUnlockedSection>]> = {
		let sections = createSections(keepUnlockedIsEnabled: enableKeepUnlockedViewModel.isOn.value)
		return Bindable(sections)
	}()

	private lazy var mainSectionFooterViewModel = KeepUnlockedMainSectionFooterViewModel(keepUnlockedIsEnabled: enableKeepUnlockedViewModel.isOn.value)
	private(set) var keepUnlockedItems = [KeepUnlockedDurationItem]()
	private let vaultKeepUnlockedSettings: VaultKeepUnlockedSettings
	private let masterkeyCacheManager: MasterkeyCacheManager
	private let fileProviderConnector: FileProviderConnector
	private let vaultInfo: VaultInfo
	private let currentKeepUnlockedDuration: Bindable<KeepUnlockedDuration?>
	private var subscriber: AnyCancellable?
	private var vaultUID: String {
		return vaultInfo.vaultUID
	}

	init(currentKeepUnlockedDuration: Bindable<KeepUnlockedDuration?>, vaultInfo: VaultInfo, vaultKeepUnlockedSettings: VaultKeepUnlockedSettings = VaultKeepUnlockedManager.shared, masterkeyCacheManager: MasterkeyCacheManager = MasterkeyCacheKeychainManager.shared, fileProviderConnector: FileProviderConnector = FileProviderXPCConnector.shared) {
		self.vaultInfo = vaultInfo
		self.vaultKeepUnlockedSettings = vaultKeepUnlockedSettings
		self.masterkeyCacheManager = masterkeyCacheManager
		self.fileProviderConnector = fileProviderConnector
		self.currentKeepUnlockedDuration = currentKeepUnlockedDuration

		self.keepUnlockedItems = KeepUnlockedDuration.allCases.map {
			return KeepUnlockedDurationItem(duration: $0, isSelected: $0 == currentKeepUnlockedDuration.value)
		}
		super.init()
		setupBinding()
	}

	func setKeepUnlockedDuration(to duration: KeepUnlockedDuration) throws {
		if let selectedKeepUnlockedItem = keepUnlockedItems.first(where: { $0.duration == duration }) {
			try vaultKeepUnlockedSettings.setKeepUnlockedDuration(selectedKeepUnlockedItem.duration, forVaultUID: vaultUID)
			currentKeepUnlockedDuration.value = selectedKeepUnlockedItem.duration
		}
	}

	func enableKeepUnlocked() -> Promise<Void> {
		let promise: Promise<Void>
		if currentKeepUnlockedDuration.value == nil {
			promise = setDefaultKeepUnlockedDurationGracefully()
		} else {
			promise = Promise(())
		}
		return promise.then {
			self.updateSections(keepUnlockedIsEnabled: true)
		}
	}

	func disableKeepUnlocked() throws {
		try vaultKeepUnlockedSettings.removeKeepUnlockedDuration(forVaultUID: vaultUID)
		try masterkeyCacheManager.removeCachedMasterkey(forVaultUID: vaultUID)
		currentKeepUnlockedDuration.value = nil
		enableKeepUnlockedViewModel.isOn.value = false
		updateSections(keepUnlockedIsEnabled: false)
	}

	func gracefulLockVault() -> Promise<Void> {
		let domainIdentifier = NSFileProviderDomainIdentifier(vaultUID)
		let getProxyPromise: Promise<VaultLocking> = fileProviderConnector.getProxy(serviceName: VaultLockingService.name, domainIdentifier: domainIdentifier)
		return getProxyPromise.then { proxy in
			proxy.gracefulLockVault(domainIdentifier: domainIdentifier)
		}.then {
			self.vaultInfo.vaultIsUnlocked.value = false
		}
	}

	func getFooterViewModel(for section: Int) -> HeaderFooterViewModel? {
		if section == 0 {
			return mainSectionFooterViewModel
		} else {
			return nil
		}
	}

	override func getFooterTitle(for section: Int) -> String? {
		if section == 1 {
			return LocalizedString.getValue("keepUnlocked.duration.footer")
		} else {
			return nil
		}
	}

	private func setupBinding() {
		subscriber = currentKeepUnlockedDuration.$value.sink { [weak self] currentKeepUnlockedDuration in
			self?.keepUnlockedItems.forEach { keepUnlockedItem in
				if keepUnlockedItem.duration == currentKeepUnlockedDuration {
					keepUnlockedItem.isSelected.value = true
				} else {
					keepUnlockedItem.isSelected.value = false
				}
			}
		}
	}

	private func createSections(keepUnlockedIsEnabled: Bool) -> [Section<VaultKeepUnlockedSection>] {
		let mainSection = createMainSection(keepUnlockedIsEnabled: keepUnlockedIsEnabled)
		if keepUnlockedIsEnabled {
			return [mainSection, keepUnlockedDurationSection]
		} else {
			return [mainSection]
		}
	}

	private func updateSections(keepUnlockedIsEnabled: Bool) {
		_sections.value = createSections(keepUnlockedIsEnabled: keepUnlockedIsEnabled)
		mainSectionFooterViewModel = KeepUnlockedMainSectionFooterViewModel(keepUnlockedIsEnabled: keepUnlockedIsEnabled)
	}

	private func createMainSection(keepUnlockedIsEnabled: Bool) -> Section<VaultKeepUnlockedSection> {
		return Section(id: VaultKeepUnlockedSection.main(unlocked: keepUnlockedIsEnabled), elements: [enableKeepUnlockedViewModel])
	}

	private func getVaultIsUnlocked() -> Promise<Bool> {
		let domainIdentifier = NSFileProviderDomainIdentifier(vaultUID)
		let getProxyPromise: Promise<VaultLocking> = fileProviderConnector.getProxy(serviceName: VaultLockingService.name, domainIdentifier: domainIdentifier)
		return getProxyPromise.then { proxy in
			proxy.getIsUnlockedVault(domainIdentifier: domainIdentifier)
		}
	}

	private func getVaultLockingProxy() -> Promise<VaultLocking> {
		let domainIdentifier = NSFileProviderDomainIdentifier(vaultUID)
		return fileProviderConnector.getProxy(serviceName: VaultLockingService.name, domainIdentifier: domainIdentifier)
	}

	private func assertVaultIsLocked() -> Promise<Void> {
		return getVaultIsUnlocked().then { vaultIsUnlocked -> Void in
			if vaultIsUnlocked {
				throw VaultKeepUnlockedViewModelError.vaultIsUnlocked
			}
		}
	}

	private func setDefaultKeepUnlockedDurationGracefully() -> Promise<Void> {
		return assertVaultIsLocked().then {
			try self.setKeepUnlockedDuration(to: self.vaultKeepUnlockedSettings.defaultKeepUnlockedDuration)
		}
	}
}

class KeepUnlockedDurationItem: TableViewCellViewModel, CheckMarkCellViewModelType {
	override var type: ConfigurableTableViewCell.Type {
		CheckMarkCell.self
	}

	var title: String? {
		return duration.description
	}

	let duration: KeepUnlockedDuration
	let isSelected: Bindable<Bool>

	init(duration: KeepUnlockedDuration, isSelected: Bool) {
		self.duration = duration
		self.isSelected = Bindable(isSelected)
	}

	override func hash(into hasher: inout Hasher) {
		hasher.combine(duration)
		hasher.combine(isSelected)
	}

	static func == (lhs: KeepUnlockedDurationItem, rhs: KeepUnlockedDurationItem) -> Bool {
		lhs.duration == rhs.duration && lhs.isSelected == rhs.isSelected
	}
}
