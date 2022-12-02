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

class VaultDetailInfoFooterViewModel: BindableAttributedTextHeaderFooterViewModel {
	private let vault: VaultInfo

	init(vault: VaultInfo) {
		self.vault = vault
		super.init(attributedText: NSAttributedString(string: ""))
		let loggedInText = createLoggedInText()
		let attributedText = createAttributedText(loggedInText: loggedInText)
		self.attributedText.value = attributedText
	}

	func createAttributedText(loggedInText: String) -> NSAttributedString {
		let infoText = loggedInText + LocalizedString.getValue("vaultDetail.info.footer.accessVault")
		let text = NSMutableAttributedString(string: infoText)
		text.append(NSAttributedString(string: " "))
		let learnMoreLink = NSAttributedString(string: LocalizedString.getValue("common.footer.learnMore"), attributes: [NSAttributedString.Key.link: URL(string: "https://docs.cryptomator.org/en/1.6/ios/access-vault/#enable-cryptomator-in-files-app")!])
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
		return String(format: LocalizedString.getValue("vaultDetail.info.footer.accountInfo"), username, vault.cloudProviderType.localizedString()) + " "
	}

	func getUsername() -> String? {
		switch vault.cloudProviderType {
		case .dropbox:
			let credential = DropboxCredential(tokenUID: vault.delegateAccountUID)
			getUsername(for: credential)
			return "(…)"
		case .googleDrive:
			let credential = GoogleDriveCredential(userID: vault.delegateAccountUID)
			return try? credential.getUsername()
		case .oneDrive:
			let credential = try? OneDriveCredential(with: vault.delegateAccountUID)
			return try? credential?.getUsername()
		case .pCloud:
			guard let credential = try? PCloudCredential(userID: vault.delegateAccountUID) else {
				return nil
			}
			getUsername(for: credential)
			return "(…)"
		case .webDAV:
			let credential = WebDAVCredentialManager.shared.getCredentialFromKeychain(with: vault.delegateAccountUID)
			return credential?.username
		case .localFileSystem:
			return nil
		case .s3:
			guard let displayName = try? S3CredentialManager.shared.getDisplayName(for: vault.delegateAccountUID) else {
				return nil
			}
			return displayName
		}
	}

	func getUsername(for credential: DropboxCredential) {
		credential.getUsername().then { username in
			let loggedInText = self.createLoggedInText(forUsername: username)
			let attributedText = self.createAttributedText(loggedInText: loggedInText)
			self.attributedText.value = attributedText
		}
	}

	func getUsername(for credential: PCloudCredential) {
		credential.getUsername().then { username in
			let loggedInText = self.createLoggedInText(forUsername: username)
			let attributedText = self.createAttributedText(loggedInText: loggedInText)
			self.attributedText.value = attributedText
		}
	}
}
