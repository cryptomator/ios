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
	var docsButtonTitle: String? { get }
	var docsURL: URL? { get }
	var forTeamsButtonTitle: String { get }
	var forTeamsURL: URL? { get }
}

class ShareVaultViewModel: ShareVaultViewModelProtocol {
	let title = LocalizedString.getValue("shareVault.title")
	let logoImageName = "cryptomator-hub-logo"
	let headerTitle: String
	let headerSubtitle: String?
	let featuresText: String?
	let hubSteps: [(String, String)]?
	let footerText: String?
	let docsButtonTitle: String?
	let docsURL: URL?
	let forTeamsButtonTitle: String
	let forTeamsURL: URL?

	init(type: ShareVaultType) {
		switch type {
		case .normal:
			headerTitle = LocalizedString.getValue("shareVault.header.title")
			headerSubtitle = nil
			featuresText = LocalizedString.getValue("shareVault.header.features")
			hubSteps = nil
			footerText = LocalizedString.getValue("shareVault.footer.text")
			docsButtonTitle = LocalizedString.getValue("shareVault.footer.link")
			docsURL = URL(string: "https://docs.cryptomator.org/security/best-practices/#sharing-of-vaults")
			forTeamsButtonTitle = LocalizedString.getValue("shareVault.button.visitHub")
			forTeamsURL = URL(string: "https://cryptomator.org/for-teams/")
		case .hub(let hubURL):
			headerTitle = LocalizedString.getValue("shareVault.hub.header.title")
			headerSubtitle = LocalizedString.getValue("shareVault.hub.header.subtitle")
			featuresText = nil
			hubSteps = [
				("1.circle.fill", LocalizedString.getValue("shareVault.hub.step1")),
				("2.circle.fill", LocalizedString.getValue("shareVault.hub.step2"))
			]
			footerText = nil
			docsButtonTitle = nil
			docsURL = nil
			forTeamsButtonTitle = LocalizedString.getValue("shareVault.hub.button.openHub")
			forTeamsURL = hubURL
		}
	}
}
