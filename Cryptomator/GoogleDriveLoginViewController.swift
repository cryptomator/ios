//
//  GoogleDriveLoginViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 18.11.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CloudAccessPrivate
import CloudAccessPrivateCore
import CryptomatorCloudAccess
import Foundation
import UIKit
class GoogleDriveLoginViewController: UIViewController {
	override func loadView() {
		let label = UILabel()
		label.text = "Google Drive"
		let loginButton = UIButton()
		loginButton.setTitle("Login", for: .normal)
		loginButton.backgroundColor = .blue
		loginButton.addTarget(self, action: #selector(login), for: .touchUpInside)
		let rootView = UIStackView(arrangedSubviews: [label, loginButton])
		rootView.backgroundColor = .white
		rootView.axis = .vertical
		rootView.spacing = 10
		view = rootView
	}

	override func viewDidLoad() {
		title = "Google Drive Login"
	}

	@objc func login() {
		let accountUID = UUID().uuidString
		let credential = GoogleDriveCredential(with: accountUID)
		GoogleDriveCloudAuthenticator.authenticate(credential: credential, from: self).then {
			print("authenticated with accountUID: \(accountUID)")

			let account = CloudProviderAccount(accountUID: accountUID, cloudProviderType: .googleDrive)
			try CloudProviderAccountManager.shared.saveNewAccount(account)
			let folderBrowserViewModel = FolderBrowserViewModel(providerAccountUID: account.accountUID, folder: CloudPath("/"))
			let folderVC = FolderBrowserViewController(viewModel: folderBrowserViewModel)
			self.navigationController?.pushViewController(folderVC, animated: true)
		}.catch { error in
			print("login error: \(error)")
		}
	}
}
