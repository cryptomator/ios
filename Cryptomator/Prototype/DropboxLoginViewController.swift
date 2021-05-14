//
//  DropboxLoginViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 01.10.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import CryptomatorCloudAccessCore
import CryptomatorCommon
import CryptomatorCommonCore
import Foundation
import Promises
import UIKit
class DropboxLoginViewController: UIViewController {
	private var vaultUIDInput: UITextField?
	// swiftlint:disable:next function_body_length
	override func loadView() {
		let rootView = UIStackView()
		rootView.backgroundColor = .white
		let accountUIDs: [String]
		do {
			accountUIDs = try CloudProviderAccountManager.shared.getAllAccountUIDs(for: .dropbox)
		} catch {
			print(error)
			let errorText = UITextView()
			errorText.text = error.localizedDescription
			rootView.addSubview(errorText)
			view = rootView
			return
		}
		if let firstAccountUID = accountUIDs.first {
			let logoutButton = ButtonWithTokenUID(frame: CGRect(x: 50, y: 100, width: 300, height: 50))
			logoutButton.tokenUID = firstAccountUID
			logoutButton.setTitle("Logout", for: .normal)
			logoutButton.backgroundColor = .red
			logoutButton.addTarget(self, action: #selector(logout), for: .touchUpInside)
			rootView.addSubview(logoutButton)

			let accountEmailText = UITextView(frame: CGRect(x: 50, y: 200, width: 300, height: 50))
			accountEmailText.text = "Loading Name"
			let credential = DropboxCredential(tokenUID: firstAccountUID)
			credential.getUsername().then { name in
				accountEmailText.text = name
			}.catch { error in
				accountEmailText.text = "Error: \(error)"
			}
			rootView.addSubview(accountEmailText)

			let folderListingButton = ButtonWithTokenUID(frame: CGRect(x: 50, y: 300, width: 300, height: 50))
			folderListingButton.tokenUID = firstAccountUID
			folderListingButton.setTitle("FolderListing", for: .normal)
			folderListingButton.backgroundColor = .blue
			folderListingButton.addTarget(self, action: #selector(folderListing), for: .touchUpInside)
			rootView.addSubview(folderListingButton)

			vaultUIDInput = UITextField(frame: CGRect(x: 50, y: 400, width: 300, height: 50))
			vaultUIDInput?.placeholder = "vaultUID"
			rootView.addSubview(vaultUIDInput!)
		} else {
			let loginButton = UIButton(frame: CGRect(x: 50, y: 100, width: 300, height: 50))
			loginButton.setTitle("Login", for: .normal)
			loginButton.backgroundColor = .blue
			loginButton.addTarget(self, action: #selector(login), for: .touchUpInside)
			rootView.addSubview(loginButton)
		}
		view = rootView
	}

	@objc func login() {
		let authenticator = DropboxAuthenticator()
		authenticator.authenticate(from: self).then { credential in
			print("authenticated with tokenUid: \(credential.tokenUID)")
			let account = CloudProviderAccount(accountUID: credential.tokenUID, cloudProviderType: .dropbox)
			try CloudProviderAccountManager.shared.saveNewAccount(account)
			let folderBrowserViewModel = FolderBrowserViewModel(providerAccountUID: account.accountUID, folder: CloudPath("/"))
			let folderVC = FolderBrowserViewController(viewModel: folderBrowserViewModel)
			self.navigationController?.pushViewController(folderVC, animated: true)
		}.catch { error in
			print("login error: \(error)")
		}
	}

	@objc func folderListing(_ sender: ButtonWithTokenUID) {
		guard let tokenUID = sender.tokenUID else {
			print("no tokenUID")
			return
		}
		let folderBrowserViewModel = FolderBrowserViewModel(providerAccountUID: tokenUID, folder: CloudPath("/"))
		let folderBrowserViewController = FolderBrowserViewController(viewModel: folderBrowserViewModel)
		navigationController?.pushViewController(folderBrowserViewController, animated: true)
	}

	@objc func logout(_ sender: ButtonWithTokenUID) {
		guard let tokenUID = sender.tokenUID else {
			print("no tokenUID")
			return
		}
		let credential = DropboxCredential(tokenUID: tokenUID)
		do {
			try VaultAccountManager.shared.removeAccount(with: tokenUID)
		} catch {
			print(error)
		}
		credential.deauthenticate()
	}
}

class ButtonWithTokenUID: UIButton {
	var tokenUID: String?
}
