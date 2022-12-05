//
//  S3AuthenticationViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 28.06.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import Combine
import CryptomatorCommonCore
import SwiftUI
import UIKit

class S3AuthenticationViewController: UIViewController {
	weak var coordinator: (Coordinator & S3Authenticating)?
	let viewModel: S3AuthenticationViewModel
	private var subscriptions = Set<AnyCancellable>()

	init(viewModel: S3AuthenticationViewModel) {
		self.viewModel = viewModel
		super.init(nibName: nil, bundle: nil)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		setupSwiftUIView()

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

	private func setupSwiftUIView() {
		let child = UIHostingController(rootView: S3AuthenticationView(viewModel: viewModel))
		addChild(child)
		view.addSubview(child.view)
		child.didMove(toParent: self)
		child.view.translatesAutoresizingMaskIntoConstraints = false
		NSLayoutConstraint.activate(child.view.constraints(equalTo: view))
	}
}
