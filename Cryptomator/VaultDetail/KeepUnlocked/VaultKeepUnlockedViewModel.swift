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

protocol VaultKeepUnlockedViewModelType {
	var title: String { get }
	var items: [KeepUnlockedItem] { get }
	func setKeepUnlockedSetting(to timeout: KeepUnlockedSetting) throws
}

class VaultKeepUnlockedViewModel: VaultKeepUnlockedViewModelType {
	var title: String {
		return LocalizedString.getValue("vaultDetail.keepUnlocked.title")
	}

	var items: [KeepUnlockedItem] {
		return keepUnlockedItems
	}

	private var keepUnlockedItems = [KeepUnlockedItem]()
	private let vaultKeepUnlockedSettings: VaultKeepUnlockedSettings
	private let masterkeyCacheManager: MasterkeyCacheManager
	private let vaultUID: String
	private let currentKeepUnlockedSetting: Bindable<KeepUnlockedSetting>

	init(currentKeepUnlockedSetting: Bindable<KeepUnlockedSetting>, vaultUID: String, vaultKeepUnlockedSettings: VaultKeepUnlockedSettings = VaultKeepUnlockedManager.shared, masterkeyCacheManager: MasterkeyCacheManager = MasterkeyCacheKeychainManager.shared) {
		self.vaultUID = vaultUID
		self.vaultKeepUnlockedSettings = vaultKeepUnlockedSettings
		self.masterkeyCacheManager = masterkeyCacheManager
		self.currentKeepUnlockedSetting = currentKeepUnlockedSetting

		self.keepUnlockedItems = KeepUnlockedSetting.allCases.map {
			return KeepUnlockedItem(timeout: $0, selected: $0 == currentKeepUnlockedSetting.value)
		}
	}

	func setKeepUnlockedSetting(to timeout: KeepUnlockedSetting) throws {
		keepUnlockedItems.forEach { keepUnlockedItem in
			if keepUnlockedItem.timeout == timeout {
				keepUnlockedItem.selected = true
			} else {
				keepUnlockedItem.selected = false
			}
		}
		if let selectedKeepUnlockedItem = items.first(where: { $0.selected }) {
			try vaultKeepUnlockedSettings.setKeepUnlockedSetting(selectedKeepUnlockedItem.timeout, forVaultUID: vaultUID)
			if case KeepUnlockedSetting.off = selectedKeepUnlockedItem.timeout {
				try masterkeyCacheManager.removeCachedMasterkey(forVaultUID: vaultUID)
			}
			currentKeepUnlockedSetting.value = selectedKeepUnlockedItem.timeout
		}
	}
}

class KeepUnlockedItem: Hashable, Equatable {
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

	static func == (lhs: KeepUnlockedItem, rhs: KeepUnlockedItem) -> Bool {
		lhs.timeout == rhs.timeout && lhs.selected == rhs.selected
	}
}
