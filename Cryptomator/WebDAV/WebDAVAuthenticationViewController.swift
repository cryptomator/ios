//
//  WebDAVAuthenticationViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 06.04.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Combine
import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import SwiftUI
import UIKit

class WebDAVAuthenticationViewController: UIViewController {
	weak var coordinator: (Coordinator & WebDAVAuthenticating)?
	private let viewModel: WebDAVAuthenticationViewModel
	private var cancellables = Set<AnyCancellable>()
	private var hud: ProgressHUD?

	init(viewModel: WebDAVAuthenticationViewModel) {
		self.viewModel = viewModel
		super.init(nibName: nil, bundle: nil)
	}

	@available(*, unavailable)
	@MainActor dynamic required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		setupSwiftUIView()

		title = "WebDAV"
		let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
		navigationItem.leftBarButtonItem = cancelButton
		let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))
		navigationItem.rightBarButtonItem = doneButton
		viewModel.$state.sink { [weak self] state in
			self?.handleState(state)
		}.store(in: &cancellables)
		viewModel.saveButtonIsEnabled.sink { saveButtonIsEnabled in
			doneButton.isEnabled = saveButtonIsEnabled
		}.store(in: &cancellables)
	}

	@objc func done() {
		viewModel.saveAccount()
	}

	func handleState(_ state: WebDAVAuthenticationViewModel.State) {
		switch state {
		case .authenticating:
			showHUD()
		case let .error(error):
			handleError(error)
		case let .authenticated(credential):
			Task {
				await hud?.transformToSelfDismissingSuccess()
				coordinator?.authenticated(with: credential)
			}
		case .insecureConnectionNotAllowed:
			showInsecureConnectionAlert()
		case let .untrustedCertificate(certificate: certificate, url: url):
			showUntrustedCertificateAlert(certificate: certificate, url: url)
		case .initial:
			break
		}
	}

	func handleError(_ error: Error) {
		Task {
			await hud?.dismiss(animated: true)
			coordinator?.handleError(error, for: self)
		}
	}

	func showHUD() {
		hud = ProgressHUD()

		hud?.text = LocalizedString.getValue("common.hud.authenticating")
		hud?.show(presentingViewController: self)
		hud?.showLoadingIndicator()
	}

	private func showUntrustedCertificateAlert(certificate: TLSCertificate, url: URL) {
		Task { [weak self] in
			await self?.hud?.dismiss(animated: true)
			let message = String(format: LocalizedString.getValue("untrustedTLSCertificate.message"), url.absoluteString, certificate.fingerprint)
			let alertController = UIAlertController(title: LocalizedString.getValue("untrustedTLSCertificate.title"),
			                                        message: message,
			                                        preferredStyle: .alert)
			let addAction = UIAlertAction(title: LocalizedString.getValue("untrustedTLSCertificate.add"),
			                              style: .default,
			                              handler: { _ in self?.viewModel.saveAccountWithCertificate() })
			alertController.addAction(addAction)
			alertController.addAction(UIAlertAction(title: LocalizedString.getValue("untrustedTLSCertificate.dismiss"), style: .cancel))
			self?.present(alertController, animated: true)
		}
	}

	private func showInsecureConnectionAlert() {
		Task { [weak self] in
			await self?.hud?.dismiss(animated: true)
			let alertController = UIAlertController(title: LocalizedString.getValue("webDAVAuthentication.httpConnection.alert.title"),
			                                        message: LocalizedString.getValue("webDAVAuthentication.httpConnection.alert.message"),
			                                        preferredStyle: .alert)
			let changeToHTTPSAction = UIAlertAction(title: LocalizedString.getValue("webDAVAuthentication.httpConnection.change"), style: .default, handler: { _ in
				self?.viewModel.saveAccountWithTransformedURL()
			})

			alertController.addAction(changeToHTTPSAction)
			alertController.preferredAction = changeToHTTPSAction
			alertController.addAction(UIAlertAction(title: LocalizedString.getValue("webDAVAuthentication.httpConnection.continue"), style: .destructive, handler: { _ in
				self?.viewModel.saveAccountWithInsecureConnection()
			}))
			self?.present(alertController, animated: true)
		}
	}

	@objc func cancel() {
		coordinator?.cancel()
	}

	private func setupSwiftUIView() {
		let child = UIHostingController(rootView: WebDAVAuthentication(viewModel: viewModel))
		addChild(child)
		view.addSubview(child.view)
		child.didMove(toParent: self)
		child.view.translatesAutoresizingMaskIntoConstraints = false
		NSLayoutConstraint.activate(child.view.constraints(equalTo: view))
	}
}

#if DEBUG
import CryptomatorCloudAccessCore
import SwiftUI

struct WebDAVAuthenticationVCPreview: PreviewProvider {
	static var previews: some View {
		WebDAVAuthenticationViewController(viewModel: .init()).toPreview()
	}
}
#endif
