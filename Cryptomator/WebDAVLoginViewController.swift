//
//  WebDAVLoginViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 03.12.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CloudAccessPrivateCore
import CryptomatorCloudAccess
import Foundation
import UIKit

class WebDAVLoginViewController: UIViewController {
	var client: WebDAVClient?
	let rootView = WebDAVLoginView()
	override func loadView() {

		rootView.loginButton.addTarget(self, action: #selector(login), for: .touchUpInside)
		view = rootView
		let tap = UITapGestureRecognizer(target: self, action: #selector(UIInputViewController.dismissKeyboard))
		view.addGestureRecognizer(tap)
	}

	@objc func dismissKeyboard() {
		view.endEditing(true)
	}

	@objc func login() {
		guard let baseURLText = rootView.baseURL.text, let username = rootView.username.text, let password = rootView.password.text else {
			return
		}
		guard let baseURL = URL(string: baseURLText) else {
			return
		}
		let credential = WebDAVCredential(baseURL: baseURL, username: username, password: password, allowedCertificate: nil)
		self.client = WebDAVClient(credential: credential, sharedContainerIdentifier: CryptomatorConstants.appGroupName, useBackgroundSession: false)
		WebDAVAuthenticator.verifyClient(client: client!).then {
			try WebDAVAuthenticator.saveCredentialToKeychain(credential, with: credential.identifier)
			let account = CloudProviderAccount(accountUID: credential.identifier, cloudProviderType: .webDAV)
			try CloudProviderAccountManager.shared.saveNewAccount(account)
			let folderBrowserViewModel = FolderBrowserViewModel(providerAccountUID: credential.identifier, folder: CloudPath("/"))
			let folderBrowserViewController = FolderBrowserViewController(viewModel: folderBrowserViewModel)
			self.navigationController?.pushViewController(folderBrowserViewController, animated: true)
		}.catch { error in
			print("login failed! \(error)")
		}
	}
}

class WebDAVLoginView: UIView {
	let baseURL = UITextField()
	let username = UITextField()
	let password = UITextField()
	let loginButton = UIButton()
	convenience init() {
		self.init(frame: CGRect.zero)

		baseURL.translatesAutoresizingMaskIntoConstraints = false
		username.translatesAutoresizingMaskIntoConstraints = false
		password.translatesAutoresizingMaskIntoConstraints = false
		loginButton.translatesAutoresizingMaskIntoConstraints = false

		baseURL.placeholder = "baseURL"
		username.placeholder = "username"
		password.placeholder = "password"
		loginButton.setTitle("Login", for: .normal)

		addSubview(baseURL)
		addSubview(username)
		addSubview(password)
		addSubview(loginButton)

		NSLayoutConstraint.activate([
			loginButton.centerXAnchor.constraint(equalTo: centerXAnchor),
			loginButton.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 10),

			loginButton.widthAnchor.constraint(equalToConstant: 200),
			loginButton.heightAnchor.constraint(equalToConstant: 100)
		])

		NSLayoutConstraint.activate([
			baseURL.centerXAnchor.constraint(equalTo: centerXAnchor),
			baseURL.topAnchor.constraint(equalTo: loginButton.bottomAnchor, constant: 10),

			baseURL.widthAnchor.constraint(equalToConstant: 200),
			baseURL.heightAnchor.constraint(equalToConstant: 50)
		])

		NSLayoutConstraint.activate([
			username.centerXAnchor.constraint(equalTo: centerXAnchor),
			username.topAnchor.constraint(equalTo: baseURL.bottomAnchor),

			username.widthAnchor.constraint(equalToConstant: 200),
			username.heightAnchor.constraint(equalToConstant: 50)
		])

		NSLayoutConstraint.activate([
			password.centerXAnchor.constraint(equalTo: centerXAnchor),
			password.topAnchor.constraint(equalTo: username.bottomAnchor),

			password.widthAnchor.constraint(equalToConstant: 200),
			password.heightAnchor.constraint(equalToConstant: 50)
		])

		backgroundColor = .white
		baseURL.autocorrectionType = .no
		username.autocorrectionType = .no
		password.autocorrectionType = .no
		password.isSecureTextEntry = true
		loginButton.backgroundColor = .blue
	}
}
