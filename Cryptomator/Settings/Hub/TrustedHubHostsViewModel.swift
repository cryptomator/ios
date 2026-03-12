//
//  TrustedHubHostsViewModel.swift
//  Cryptomator
//
//  Created by Tobias Hagemann on 12.03.26.
//  Copyright © 2026 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import Foundation

class TrustedHubHostsViewModel {
	var title: String {
		return LocalizedString.getValue("settings.hub.trustedHosts")
	}

	var emptyListMessage: String {
		return LocalizedString.getValue("trustedHubHosts.emptyList.message")
	}

	var hosts: [String] {
		return cryptomatorSettings.trustedHubAuthorities.sorted()
	}

	private var cryptomatorSettings: CryptomatorSettings

	init(cryptomatorSettings: CryptomatorSettings = CryptomatorUserDefaults.shared) {
		self.cryptomatorSettings = cryptomatorSettings
	}

	func removeHost(_ host: String) {
		var authorities = cryptomatorSettings.trustedHubAuthorities
		authorities.remove(host)
		cryptomatorSettings.trustedHubAuthorities = authorities
	}

	func clearAllHosts() {
		cryptomatorSettings.trustedHubAuthorities = []
	}
}
