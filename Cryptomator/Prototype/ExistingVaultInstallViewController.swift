//
//  ExistingVaultInstallViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 10.11.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CloudAccessPrivateCore
import CryptomatorCloudAccess
import Foundation
import UIKit
class ExistingVaultInstallViewController: UIViewController {
	let viewModel: ExistingVaultInstallerViewModel
	private var passwordInput: UITextField?
	weak var coordinator: AddVaultCoordinator?
	override func loadView() {
		let rootView = UIView()
		rootView.backgroundColor = .white
		passwordInput = UITextField()
		passwordInput?.frame = CGRect(x: 50, y: 100, width: 300, height: 50)
		passwordInput?.placeholder = "Passsword"
		passwordInput?.isSecureTextEntry = true
		rootView.addSubview(passwordInput!)

		let installButton = UIButton(frame: CGRect(x: 50, y: 200, width: 300, height: 50))
		installButton.setTitle("Install", for: .normal)
		installButton.backgroundColor = .green
		installButton.addTarget(self, action: #selector(installVault), for: .touchUpInside)
		rootView.addSubview(installButton)
		view = rootView
	}

	init(viewModel: ExistingVaultInstallerViewModel) {
		self.viewModel = viewModel
		super.init(nibName: nil, bundle: nil)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	@objc func installVault() {
		guard let password = passwordInput?.text, !password.isEmpty else {
			print("password empty")
			return
		}
		viewModel.installVault(withPassword: password).then { vaultUID in
			let alert = UIAlertController(title: "Success", message: "Installed Vault: \(vaultUID). You can now use it with the FileProviderExtension", preferredStyle: .alert)
			alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: {_ in
				self.coordinator?.close()
			}))
			self.present(alert, animated: true, completion: nil)
		}.catch { error in
			let alert = UIAlertController(title: "Error", message: "Install Vault \(self.viewModel.masterkeyPath.lastPathComponent) failed with error: \(error)", preferredStyle: .alert)
			alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
			self.present(alert, animated: true, completion: nil)
		}
	}
}
