//
//  ShareVaultViewModel.swift
//  Cryptomator
//
//  Created by Majid Achhoud on 24.10.25.
//  Copyright © 2025 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import Foundation

enum ShareVaultType {
	case normal
	case hub(URL)
}

protocol ShareVaultViewModelProtocol: AnyObject {
	var title: String { get }
	var logoImageName: String { get }
	var headerTitle: String { get }
	var headerSubtitle: String? { get }
	var featuresText: String? { get }
	var hubSteps: [(String, String)]? { get }
	var footerText: String? { get }
	var docsURL: URL? { get }
	var hubButtonTitle: String { get }
	var hubURL: URL? { get }
}

class ShareVaultViewModel: ShareVaultViewModelProtocol, ObservableObject {
	let title = LocalizedString.getValue("shareVault.title")
	let logoImageName = "cryptomator-hub-logo"
	let headerTitle: String
	let headerSubtitle: String?
	let featuresText: String?
	let hubSteps: [(String, String)]?
	let footerText: String?
	let docsURL: URL?
	let hubButtonTitle: String
	let hubURL: URL?

	init(type: ShareVaultType) {
		switch type {
		case .normal:
			self.headerTitle = LocalizedString.getValue("shareVault.normal.header.title")
			self.headerSubtitle = nil
			self.featuresText = LocalizedString.getValue("shareVault.normal.header.features")
			self.hubSteps = nil
			self.footerText = LocalizedString.getValue("shareVault.normal.footer.text")
			self.docsURL = URL(string: "https://docs.cryptomator.org/security/best-practices/#sharing-of-vaults")
			self.hubButtonTitle = LocalizedString.getValue("shareVault.normal.button.visitHub")
			self.hubURL = URL(string: "https://cryptomator.org/for-teams/")
		case let .hub(hubURL):
			self.headerTitle = LocalizedString.getValue("shareVault.hub.header.title")
			self.headerSubtitle = LocalizedString.getValue("shareVault.hub.header.subtitle")
			self.featuresText = nil
			self.hubSteps = [
				("1.circle.fill", LocalizedString.getValue("shareVault.hub.step1")),
				("2.circle.fill", LocalizedString.getValue("shareVault.hub.step2"))
			]
			self.footerText = nil
			self.docsURL = nil
			self.hubButtonTitle = LocalizedString.getValue("shareVault.hub.button.openHub")
			self.hubURL = hubURL
		}
	}
}
