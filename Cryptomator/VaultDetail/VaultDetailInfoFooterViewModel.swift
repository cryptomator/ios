//
//  VaultDetailInfoFooterViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 05.08.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import Foundation
import UIKit

class VaultDetailInfoFooterViewModel: AttributedTextHeaderFooterViewModel {
	private let vault: VaultInfo

	init(vault: VaultInfo) {
		self.vault = vault
		super.init(attributedText: NSAttributedString(string: ""))
		let loggedInText = createLoggedInText()
		let attributedText = createAttributedText(loggedInText: loggedInText)
		self.attributedText.value = attributedText
	}

	func createAttributedText(loggedInText: String) -> NSAttributedString {
		let infoText = loggedInText + NSLocalizedString("vaultDetail.info.footer.accessVault", comment: "")

		let text = NSMutableAttributedString(string: infoText)
		text.append(NSAttributedString(string: " "))
		let learnMoreLink = NSAttributedString(string: NSLocalizedString("common.footer.learnMore", comment: ""), attributes: [NSAttributedString.Key.link: URL(string: "https://cryptomator.org")!]) // TODO: replace link
		text.append(learnMoreLink)
		return text
	}

	func createLoggedInText() -> String {
		guard let username = getUsername() else {
			return ""
		}
		return createLoggedInText(forUsername: username)
	}

	func createLoggedInText(forUsername username: String) -> String {
		return String(format: NSLocalizedString("vaultDetail.info.footer.accountInfo", comment: ""), username, vault.cloudProviderType.localizedString()) + " "
	}

	func getUsername() -> String? {
		switch vault.cloudProviderType {
		case .dropbox:
			let credential = DropboxCredential(tokenUID: vault.delegateAccountUID)
			getUsername(for: credential)
			return "(…)"
		case .googleDrive:
			let credential = GoogleDriveCredential(tokenUID: vault.delegateAccountUID)
			return try? credential.getUsername()
		case .oneDrive:
			let credential = try? OneDriveCredential(with: vault.delegateAccountUID)
			return try? credential?.getUsername()
		case .webDAV:
			let credential = WebDAVAuthenticator.getCredentialFromKeychain(with: vault.delegateAccountUID)
			return credential?.username
		case .localFileSystem:
			return nil
		}
	}

	func getUsername(for credential: DropboxCredential) {
		credential.getUsername().then { username in
			let loggedInText = self.createLoggedInText(forUsername: username)
			let attributedText = self.createAttributedText(loggedInText: loggedInText)
			self.attributedText.value = attributedText
		}
	}
}
