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
	func setKeepUnlockedDuration(to duration: KeepUnlockedDuration) throws
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
	private let currentKeepUnlockedDuration: Bindable<KeepUnlockedDuration?>

	init(currentKeepUnlockedDuration: Bindable<KeepUnlockedDuration?>, vaultUID: String, vaultKeepUnlockedSettings: VaultKeepUnlockedSettings = VaultKeepUnlockedManager.shared, masterkeyCacheManager: MasterkeyCacheManager = MasterkeyCacheKeychainManager.shared) {
		self.vaultUID = vaultUID
		self.vaultKeepUnlockedSettings = vaultKeepUnlockedSettings
		self.masterkeyCacheManager = masterkeyCacheManager
		self.currentKeepUnlockedDuration = currentKeepUnlockedDuration

		self.keepUnlockedItems = KeepUnlockedDuration.allCases.map {
			return KeepUnlockedItem(duration: $0, selected: $0 == currentKeepUnlockedDuration.value)
		}
	}

	func setKeepUnlockedDuration(to duration: KeepUnlockedDuration) throws {
		keepUnlockedItems.forEach { keepUnlockedItem in
			if keepUnlockedItem.duration == duration {
				keepUnlockedItem.selected = true
			} else {
				keepUnlockedItem.selected = false
			}
		}
		if let selectedKeepUnlockedItem = items.first(where: { $0.selected }) {
			try vaultKeepUnlockedSettings.setKeepUnlockedDuration(selectedKeepUnlockedItem.duration, forVaultUID: vaultUID)
			currentKeepUnlockedDuration.value = selectedKeepUnlockedItem.duration
		}
	}
}

class KeepUnlockedItem: Hashable, Equatable {
	let duration: KeepUnlockedDuration
	var selected: Bool

	init(duration: KeepUnlockedDuration, selected: Bool) {
		self.duration = duration
		self.selected = selected
	}

	func hash(into hasher: inout Hasher) {
		hasher.combine(duration)
		hasher.combine(selected)
	}

	static func == (lhs: KeepUnlockedItem, rhs: KeepUnlockedItem) -> Bool {
		lhs.duration == rhs.duration && lhs.selected == rhs.selected
	}
}
