//
//  VaultDetailUnlockVaultViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 04.08.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Combine
import CryptomatorCommonCore
import CryptomatorCryptoLib
import UIKit

class VaultDetailUnlockVaultViewController: SingleSectionStaticUITableViewController {
	weak var coordinator: (Coordinator & VaultPasswordVerifying)?
	lazy var enableButton: UIBarButtonItem = {
		let button = UIBarButtonItem(title: LocalizedString.getValue("common.button.enable"), style: .done, target: self, action: #selector(verify))
		button.isEnabled = false
		return button
	}()

	private var viewModel: VaultDetailUnlockVaultViewModel

	private var viewToShake: UIView? {
		return navigationController?.view.superview // shake the whole modal dialog
	}

	private lazy var subscribers = Set<AnyCancellable>()

	init(viewModel: VaultDetailUnlockVaultViewModel) {
		self.viewModel = viewModel
		super.init(viewModel: viewModel)
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = viewModel.title
		navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
		navigationItem.rightBarButtonItem = enableButton
		viewModel.enableVerifyButton.sink { [weak self] isEnabled in
			self?.enableButton.isEnabled = isEnabled
		}.store(in: &subscribers)
		viewModel.lastReturnButtonPressed.sink { [weak self] in
			self?.verify()
		}.store(in: &subscribers)
	}

	override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
		super.viewWillTransition(to: size, with: coordinator)
		viewToShake?.cancelShaking()
	}

	@objc func cancel() {
		coordinator?.cancel()
	}

	@objc func verify() {
		do {
			try viewModel.unlockVault()
			coordinator?.verifiedVaultPassword()
		} catch MasterkeyFileError.invalidPassphrase {
			viewToShake?.shake()
		} catch {
			coordinator?.handleError(error, for: self)
		}
	}
}
