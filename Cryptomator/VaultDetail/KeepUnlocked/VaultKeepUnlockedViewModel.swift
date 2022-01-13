//
//  VaultKeepUnlockedViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 30.12.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Combine
import CryptomatorCommonCore
import Foundation

protocol VaultAutoLockViewModelType {
	var title: String { get }
	var items: [AutoLockItem] { get }
	func setKeepUnlockedSetting(to timeout: KeepUnlockedSetting) throws
}

class VaultKeepUnlockedViewModel: VaultAutoLockViewModelType {
	var title: String {
		return LocalizedString.getValue("vaultDetail.keepUnlocked.title")
	}

	var items: [AutoLockItem] {
		return autoLockItems
	}

	private var autoLockItems = [AutoLockItem]()
	private let vaultKeepUnlockedSettings: VaultKeepUnlockedSettings
	private let masterkeyCacheManager: MasterkeyCacheManager
	private let vaultUID: String
	private let currentKeepUnlockedSetting: Bindable<KeepUnlockedSetting>

	init(currentKeepUnlockedSetting: Bindable<KeepUnlockedSetting>, vaultUID: String, vaultKeepUnlockedSettings: VaultKeepUnlockedSettings = VaultKeepUnlockedManager.shared, masterkeyCacheManager: MasterkeyCacheManager = MasterkeyCacheKeychainManager.shared) {
		self.vaultUID = vaultUID
		self.vaultKeepUnlockedSettings = vaultKeepUnlockedSettings
		self.masterkeyCacheManager = masterkeyCacheManager
		self.currentKeepUnlockedSetting = currentKeepUnlockedSetting

		self.autoLockItems = KeepUnlockedSetting.allCases.map {
			return AutoLockItem(timeout: $0, selected: $0 == currentKeepUnlockedSetting.value)
		}
	}

	func setKeepUnlockedSetting(to timeout: KeepUnlockedSetting) throws {
		autoLockItems.forEach { autoLockItem in
			if autoLockItem.timeout == timeout {
				autoLockItem.selected = true
			} else {
				autoLockItem.selected = false
			}
		}
		if let selectedAutoLockItem = items.first(where: { $0.selected }) {
			try vaultKeepUnlockedSettings.setKeepUnlockedSetting(selectedAutoLockItem.timeout, forVaultUID: vaultUID)
			if case KeepUnlockedSetting.off = selectedAutoLockItem.timeout {
				try masterkeyCacheManager.removeCachedMasterkey(forVaultUID: vaultUID)
			}
			currentKeepUnlockedSetting.value = selectedAutoLockItem.timeout
		}
	}
}

class AutoLockItem: Hashable, Equatable {
	let timeout: KeepUnlockedSetting
	var selected: Bool

	init(timeout: KeepUnlockedSetting, selected: Bool) {
		self.timeout = timeout
		self.selected = selected
	}

	func hash(into hasher: inout Hasher) {
		hasher.combine(timeout)
		hasher.combine(selected)
	}

	static func == (lhs: AutoLockItem, rhs: AutoLockItem) -> Bool {
		lhs.timeout == rhs.timeout && lhs.selected == rhs.selected
	}
}
