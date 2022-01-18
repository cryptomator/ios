//
//  UnlockSectionFooterViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 03.08.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import Foundation

class UnlockSectionFooterViewModel: HeaderFooterViewModel {
	var viewType: HeaderFooterViewModelConfiguring.Type { return BaseHeaderFooterView.self }
	let title: Bindable<String?>
	var vaultUnlocked: Bool {
		didSet {
			updateTitle()
		}
	}

	var biometricalUnlockEnabled: Bool {
		didSet {
			updateTitle()
		}
	}

	var keepUnlockedDuration: KeepUnlockedDuration {
		didSet {
			updateTitle()
		}
	}

	var biometryTypeName: String?

	init(vaultUnlocked: Bool, biometricalUnlockEnabled: Bool, biometryTypeName: String?, keepUnlockedDuration: KeepUnlockedDuration) {
		self.vaultUnlocked = vaultUnlocked
		self.biometricalUnlockEnabled = biometricalUnlockEnabled
		self.biometryTypeName = biometryTypeName
		let titleText = UnlockSectionFooterViewModel.getTitleText(vaultUnlocked: vaultUnlocked, biometricalUnlockEnabled: biometricalUnlockEnabled, biometryTypeName: biometryTypeName, keepUnlockedDuration: keepUnlockedDuration)
		self.title = Bindable(titleText)
		self.keepUnlockedDuration = keepUnlockedDuration
	}

	private func updateTitle() {
		title.value = UnlockSectionFooterViewModel.getTitleText(vaultUnlocked: vaultUnlocked, biometricalUnlockEnabled: biometricalUnlockEnabled, biometryTypeName: biometryTypeName, keepUnlockedDuration: keepUnlockedDuration)
	}

	private static func getTitleText(vaultUnlocked: Bool, biometricalUnlockEnabled: Bool, biometryTypeName: String?, keepUnlockedDuration: KeepUnlockedDuration) -> String {
		let unlockedText: String
		if vaultUnlocked {
			unlockedText = LocalizedString.getValue("vaultDetail.unlocked.footer")
		} else {
			unlockedText = LocalizedString.getValue("vaultDetail.locked.footer")
		}
		let keepUnlockedText: String
		switch keepUnlockedDuration {
		case .auto:
			keepUnlockedText = LocalizedString.getValue("vaultDetail.keepUnlocked.footer.off")
		case .indefinite:
			keepUnlockedText = LocalizedString.getValue("vaultDetail.keepUnlocked.footer.unlimitedDuration")
		case .fiveMinutes, .tenMinutes, .thirtyMinutes, .oneHour:
			keepUnlockedText = String(format: LocalizedString.getValue("vaultDetail.keepUnlocked.footer.limitedDuration"), keepUnlockedDuration.description ?? "")
		}
		var footerText = "\(unlockedText)\n\n\(keepUnlockedText)"
		if let biometryTypeName = biometryTypeName {
			let biometricalUnlockText: String
			if biometricalUnlockEnabled {
				biometricalUnlockText = String(format: LocalizedString.getValue("vaultDetail.enabledBiometricalUnlock.footer"), biometryTypeName)
			} else {
				biometricalUnlockText = String(format: LocalizedString.getValue("vaultDetail.disabledBiometricalUnlock.footer"), biometryTypeName)
			}
			footerText += "\n\n\(biometricalUnlockText)"
		}
		return footerText
	}
}
