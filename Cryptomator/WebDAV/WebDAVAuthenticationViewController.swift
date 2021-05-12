//
//  WebDAVAuthenticationViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 06.04.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import UIKit

class WebDAVAuthenticationViewController: SingleSectionTableViewController {
	weak var coordinator: (Coordinator & WebDAVAuthenticating)?

	private var viewModel: WebDAVAuthenticationViewModelProtocol

	init(viewModel: WebDAVAuthenticationViewModelProtocol) {
		self.viewModel = viewModel
		super.init()
	}

	private var cells: [TextFieldCell] {
		return [urlCell, usernameCell, passwordCell]
	}

	private lazy var urlCell: URLFieldCell = {
		let urlCell = URLFieldCell(style: .default, reuseIdentifier: "URLFieldCell")
		urlCell.textField.placeholder = NSLocalizedString("common.cells.url", comment: "")
		urlCell.textField.text = "https://"
		urlCell.textField.becomeFirstResponder()
		return urlCell
	}()

	private lazy var usernameCell: UsernameFieldCell = {
		let usernameCell = UsernameFieldCell(style: .default, reuseIdentifier: "UsernameFieldCell")
		usernameCell.textField.placeholder = NSLocalizedString("common.cells.username", comment: "")
		return usernameCell
	}()

	private lazy var passwordCell: PasswordFieldCell = {
		let passwordCell = PasswordFieldCell(style: .default, reuseIdentifier: "PasswordFieldCell")
		passwordCell.textField.placeholder = NSLocalizedString("common.cells.password", comment: "")
		return passwordCell
	}()

	override func viewDidLoad() {
		super.viewDidLoad()
		title = NSLocalizedString("webDAVAuthentication.title", comment: "")
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
		viewModel.addAccount(url: urlCell.textField.text, username: usernameCell.textField.text, password: passwordCell.textField.text, allowedCertificate: allowedCertificate).then { [weak self] credential in
			guard let self = self else { return }
			self.coordinator?.authenticated(with: credential)
		}.catch { [weak self] error in
			guard let self = self else { return }
			if case let WebDAVAuthenticationError.untrustedCertificate(certificate: certificate, url: url) = error {
				self.coordinator?.handleUntrustedCertificate(certificate, url: url, for: self, viewModel: self.viewModel)
			} else {
				self.coordinator?.handleError(error, for: self)
			}
		}
	}

	@objc func cancel() {
		coordinator?.cancel()
	}

	// MARK: - UITableViewDataSource

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return 3
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		return cells[indexPath.row]
	}
}

#if DEBUG
import CryptomatorCloudAccessCore
import Promises
import SwiftUI

class WebDAVAuthenticationViewModelMock: WebDAVAuthenticationViewModelProtocol {
	func addAccount(url: String?, username: String?, password: String?, allowedCertificate: Data?) -> Promise<WebDAVCredential> {
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
