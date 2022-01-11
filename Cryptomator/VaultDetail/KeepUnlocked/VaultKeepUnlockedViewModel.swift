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
	func setAutoLockTimeout(to timeout: AutoLockTimeout) throws
}

class VaultKeepUnlockedViewModel: VaultAutoLockViewModelType {
	var title: String {
		return LocalizedString.getValue("vaultDetail.keepUnlocked.title")
	}

	var items: [AutoLockItem] {
		return autoLockItems
	}

	private var autoLockItems = [AutoLockItem]()
	private let vaultAutoLockSettings: VaultAutoLockingSettings
	private let vaultUID: String
	private let currentAutoLockTimeout: Bindable<AutoLockTimeout>

	init(currentAutoLockTimeout: Bindable<AutoLockTimeout>, vaultUID: String, vaultAutoLockSettings: VaultAutoLockingSettings = VaultAutoLockingManager.shared) {
		self.vaultUID = vaultUID
		self.vaultAutoLockSettings = vaultAutoLockSettings
		self.currentAutoLockTimeout = currentAutoLockTimeout

		self.autoLockItems = AutoLockTimeout.allCases.map {
			return AutoLockItem(timeout: $0, selected: $0 == currentAutoLockTimeout.value)
		}
	}

	func setAutoLockTimeout(to timeout: AutoLockTimeout) throws {
		autoLockItems.forEach { autoLockItem in
			if autoLockItem.timeout == timeout {
				autoLockItem.selected = true
			} else {
				autoLockItem.selected = false
			}
		}
		if let selectedAutoLockItem = items.first(where: { $0.selected }) {
			try vaultAutoLockSettings.setAutoLockTimeout(selectedAutoLockItem.timeout, forVaultUID: vaultUID)
			currentAutoLockTimeout.value = selectedAutoLockItem.timeout
		}
	}
}

class AutoLockItem: Hashable, Equatable {
	let timeout: AutoLockTimeout
	var selected: Bool

	init(timeout: AutoLockTimeout, selected: Bool) {
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
