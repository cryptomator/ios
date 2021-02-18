//
//  GoogleDriveAccountOverviewViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 18.11.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CloudAccessPrivateCore
import CryptomatorCloudAccess
import FileProvider
import Foundation
import UIKit
class GoogleDriveAccountOverviewViewController: UIViewController {
	let credential: GoogleDriveCredential

	init(for credential: GoogleDriveCredential) {
		self.credential = credential
		super.init(nibName: nil, bundle: nil)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func loadView() {
		let rootView = AccountOverview()

		rootView.logoutButton.setTitle("Logout", for: .normal)
		rootView.logoutButton.addTarget(self, action: #selector(logout), for: .touchUpInside)

		rootView.folderListingButton.setTitle("Choose existing Vault", for: .normal)
		rootView.folderListingButton.addTarget(self, action: #selector(chooseExistingVault), for: .touchUpInside)

		view = rootView
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = "GDrive - Account Overview"
	}

	@objc func logout() {
		VaultManager.shared.removeVault(withUID: credential.tokenUid).then(on: .main) {
			self.credential.deauthenticate()
			self.navigationController?.popToRootViewController(animated: true)
		}.catch { error in
			print(error)
		}
	}

	@objc func chooseExistingVault() {
		let folderBrowserViewModel = FolderBrowserViewModel(providerAccountUID: credential.tokenUid, folder: CloudPath("/"))
		let folderBrowserViewController = FolderBrowserViewController(viewModel: folderBrowserViewModel)
		navigationController?.pushViewController(folderBrowserViewController, animated: true)
	}
}

class AccountOverview: UIView {
	let logoutButton = UIButton()
	let folderListingButton = UIButton()

	convenience init() {
		self.init(frame: CGRect.zero)

		logoutButton.translatesAutoresizingMaskIntoConstraints = false
		folderListingButton.translatesAutoresizingMaskIntoConstraints = false

		addSubview(logoutButton)
		addSubview(folderListingButton)

		NSLayoutConstraint.activate([
			logoutButton.centerXAnchor.constraint(equalTo: centerXAnchor),
			logoutButton.centerYAnchor.constraint(equalTo: centerYAnchor),

			logoutButton.widthAnchor.constraint(equalToConstant: 200),
			logoutButton.heightAnchor.constraint(equalToConstant: 100)
		])

		NSLayoutConstraint.activate([
			folderListingButton.centerXAnchor.constraint(equalTo: centerXAnchor),
			folderListingButton.topAnchor.constraint(equalTo: logoutButton.bottomAnchor, constant: 10),

			folderListingButton.widthAnchor.constraint(equalToConstant: 200),
			folderListingButton.heightAnchor.constraint(equalToConstant: 100)
		])

		backgroundColor = .white
		logoutButton.backgroundColor = .red
		folderListingButton.backgroundColor = .blue
	}
}
