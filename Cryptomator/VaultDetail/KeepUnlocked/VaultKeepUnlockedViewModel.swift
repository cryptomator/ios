//
//  VaultKeepUnlockedViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 30.12.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Combine
import CryptomatorCommonCore
import Dependencies
import FileProvider
import Foundation
import Promises

protocol VaultKeepUnlockedViewModelType: TableViewModel<VaultKeepUnlockedSection> {
	func getFooterViewModel(forSection section: Int) -> HeaderFooterViewModel?
	func setKeepUnlockedDuration(to duration: KeepUnlockedDuration) -> Promise<Void>
	func gracefulLockVault() -> Promise<Void>
}

enum VaultKeepUnlockedSection: Hashable {
	case main
}

enum VaultKeepUnlockedViewModelError: Error {
	case vaultIsUnlocked
}

class VaultKeepUnlockedViewModel: TableViewModel<VaultKeepUnlockedSection>, VaultKeepUnlockedViewModelType {
	override var title: String {
		return LocalizedString.getValue("vaultDetail.keepUnlocked.title")
	}

	override var sections: [Section<VaultKeepUnlockedSection>] {
		return [Section<VaultKeepUnlockedSection>(id: .main, elements: keepUnlockedItems)]
	}

	private lazy var sectionFooterViewModel = KeepUnlockedSectionFooterViewModel(keepUnlockedDuration: currentKeepUnlockedDuration)

	private(set) var keepUnlockedItems = [KeepUnlockedDurationItem]()
	private let vaultKeepUnlockedSettings: VaultKeepUnlockedSettings
	private let masterkeyCacheManager: MasterkeyCacheManager
	@Dependency(\.fileProviderConnector) private var fileProviderConnector
	private let vaultInfo: VaultInfo
	private let currentKeepUnlockedDuration: Bindable<KeepUnlockedDuration>
	private var subscriber: AnyCancellable?
	private var vaultUID: String {
		return vaultInfo.vaultUID
	}

	init(currentKeepUnlockedDuration: Bindable<KeepUnlockedDuration>, vaultInfo: VaultInfo, vaultKeepUnlockedSettings: VaultKeepUnlockedSettings = VaultKeepUnlockedManager.shared, masterkeyCacheManager: MasterkeyCacheManager = MasterkeyCacheKeychainManager.shared) {
		self.vaultInfo = vaultInfo
		self.vaultKeepUnlockedSettings = vaultKeepUnlockedSettings
		self.masterkeyCacheManager = masterkeyCacheManager
		self.currentKeepUnlockedDuration = currentKeepUnlockedDuration

		self.keepUnlockedItems = KeepUnlockedDuration.allCases.map {
			return KeepUnlockedDurationItem(duration: $0, isSelected: $0 == currentKeepUnlockedDuration.value)
		}
		super.init()
		setupBinding()
	}

	func setKeepUnlockedDuration(to duration: KeepUnlockedDuration) -> Promise<Void> {
		let promise: Promise<Void>
		if currentKeepUnlockedDuration.value == .auto, duration != .auto {
			promise = assertVaultIsLocked()
		} else {
			promise = Promise(())
		}
		return promise.then { [self] in
			if let selectedKeepUnlockedItem = keepUnlockedItems.first(where: { $0.duration == duration }) {
				try vaultKeepUnlockedSettings.setKeepUnlockedDuration(selectedKeepUnlockedItem.duration, forVaultUID: vaultUID)
				currentKeepUnlockedDuration.value = selectedKeepUnlockedItem.duration
				if case KeepUnlockedDuration.auto = duration {
					try masterkeyCacheManager.removeCachedMasterkey(forVaultUID: vaultUID)
				}
			}
		}
	}

	func gracefulLockVault() -> Promise<Void> {
		let domainIdentifier = NSFileProviderDomainIdentifier(vaultUID)
		let getXPCPromise: Promise<XPC<VaultLocking>> = fileProviderConnector.getXPC(serviceName: .vaultLocking, domainIdentifier: domainIdentifier)
		return getXPCPromise.then { xpc in
			xpc.proxy.gracefulLockVault(domainIdentifier: domainIdentifier)
		}.then {
			self.vaultInfo.vaultIsUnlocked.value = false
		}.always {
			self.fileProviderConnector.invalidateXPC(getXPCPromise)
		}
	}

	func getFooterViewModel(forSection section: Int) -> HeaderFooterViewModel? {
		if section == 0 {
			return sectionFooterViewModel
		} else {
			return nil
		}
	}

	override func getHeaderTitle(for section: Int) -> String? {
		return LocalizedString.getValue("keepUnlocked.header")
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

	private func getVaultIsUnlocked() -> Promise<Bool> {
		let domainIdentifier = NSFileProviderDomainIdentifier(vaultUID)
		let getXPCPromise: Promise<XPC<VaultLocking>> = fileProviderConnector.getXPC(serviceName: .vaultLocking, domainIdentifier: domainIdentifier)
		return getXPCPromise.then { xpc in
			return xpc.proxy.getIsUnlockedVault(domainIdentifier: domainIdentifier)
		}.always {
			self.fileProviderConnector.invalidateXPC(getXPCPromise)
		}
	}

	private func assertVaultIsLocked() -> Promise<Void> {
		return getVaultIsUnlocked().then { vaultIsUnlocked -> Void in
			if vaultIsUnlocked {
				throw VaultKeepUnlockedViewModelError.vaultIsUnlocked
			}
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
