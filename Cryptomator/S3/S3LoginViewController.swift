//
//  S3LoginViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 28.06.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import Combine
import CryptomatorCommonCore
import SwiftUI
import UIKit

class S3LoginViewController: UIHostingController<S3LoginView> {
	weak var coordinator: (Coordinator & S3Authenticating)?
	let viewModel: S3LoginViewModel
	private var subscriptions = Set<AnyCancellable>()

	init(viewModel: S3LoginViewModel) {
		self.viewModel = viewModel
		super.init(rootView: S3LoginView(viewModel: viewModel))
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))
		navigationItem.rightBarButtonItem = doneButton
		let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
		navigationItem.leftBarButtonItem = cancelButton
		title = viewModel.title

		viewModel.saveDisabled.sink { disabled in
			doneButton.isEnabled = !disabled
		}.store(in: &subscriptions)

		let hud = ProgressHUD()
		hud.text = LocalizedString.getValue("common.hud.authenticating")
		viewModel.$loginState.sink { [weak self] state in
			switch state {
			case let .error(error):
				self?.handleError(error, coordinator: self?.coordinator, progressHUD: hud)
			case .verifyingCredentials:
				guard let self = self else { return }
				hud.show(presentingViewController: self)
			case let .loggedIn(credential):
				hud.dismiss(animated: true).then {
					self?.coordinator?.authenticated(with: credential)
				}
			case .notLoggedIn:
				break
			}
		}.store(in: &subscriptions)
	}

	@objc func done() {
		viewModel.saveS3Credential()
	}

	@objc func cancel() {
		coordinator?.cancel()
	}
}
