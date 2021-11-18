//
//  WebDAVAuthenticationViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 06.04.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import UIKit

class WebDAVAuthenticationViewController: SingleSectionStaticUITableViewController {
	weak var coordinator: (Coordinator & WebDAVAuthenticating)?
	private var viewModel: WebDAVAuthenticationViewModelProtocol

	init(viewModel: WebDAVAuthenticationViewModelProtocol) {
		self.viewModel = viewModel
		super.init(viewModel: viewModel)
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = LocalizedString.getValue("webDAVAuthentication.title")
		tableView.rowHeight = 44
		let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
		navigationItem.leftBarButtonItem = cancelButton
		let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))
		navigationItem.rightBarButtonItem = doneButton
	}

	@objc func done() {
		addAccount(allowedCertificate: nil)
	}

	func addAccount(allowedCertificate: Data?) {
		let credential: WebDAVCredential
		do {
			credential = try viewModel.createWebDAVCredentialFromInput(allowedCertificate: allowedCertificate)
		} catch {
			coordinator?.handleError(error, for: self)
			return
		}

		let hud = ProgressHUD()
		hud.text = LocalizedString.getValue("webDAVAuthentication.progress")
		hud.show(presentingViewController: self)
		hud.showLoadingIndicator()
		let addAccountPromise = viewModel.addAccount(credential: credential)
		addAccountPromise.then { _ in
			hud.transformToSelfDismissingSuccess()
		}.then {
			addAccountPromise
		}.then { [weak self] credential in
			guard let self = self else { return }
			self.coordinator?.authenticated(with: credential)
		}.catch { [weak self] error in
			self?.handleError(error, hud: hud)
		}
	}

	@objc func cancel() {
		coordinator?.cancel()
	}

	private func handleError(_ error: Error, hud: ProgressHUD) {
		hud.dismiss(animated: true).then { [weak self] in
			self?.handleError(error)
		}
	}

	private func handleError(_ error: Error) {
		if case let WebDAVAuthenticationError.untrustedCertificate(certificate: certificate, url: url) = error {
			coordinator?.handleUntrustedCertificate(certificate, url: url, for: self, viewModel: viewModel)
		} else {
			coordinator?.handleError(error, for: self)
		}
	}
}

#if DEBUG
import CryptomatorCloudAccessCore
import Promises
import SwiftUI

class WebDAVAuthenticationViewModelMock: SingleSectionTableViewModel, WebDAVAuthenticationViewModelProtocol {
	func createWebDAVCredentialFromInput(allowedCertificate: Data?) throws -> WebDAVCredential {
		WebDAVCredential(baseURL: URL(string: ".")!, username: "", password: "", allowedCertificate: nil)
	}

	func addAccount(credential: WebDAVCredential) -> Promise<WebDAVCredential> {
		return Promise(WebDAVCredential(baseURL: URL(string: ".")!, username: "", password: "", allowedCertificate: nil))
	}
}

struct WebDAVAuthenticationVCPreview: PreviewProvider {
	static var previews: some View {
		let mock = WebDAVAuthenticationViewModelMock()
		WebDAVAuthenticationViewController(viewModel: mock).toPreview()
	}
}
#endif
