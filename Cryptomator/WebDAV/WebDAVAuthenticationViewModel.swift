//
//  WebDAVAuthenticationViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 07.04.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import Foundation
import Promises

enum WebDAVAuthenticationError: Error {
	case invalidInput
	case untrustedCertificate(certificate: TLSCertificate, url: URL)
	case userCanceled
}

protocol WebDAVAuthenticationViewModelProtocol {
	func addAccount(url: String?, username: String?, password: String?, allowedCertificate: Data?) -> Promise<WebDAVCredential>
}

class WebDAVAuthenticationViewModel: WebDAVAuthenticationViewModelProtocol {
	private var client: WebDAVClient?
	func addAccount(url: String?, username: String?, password: String?, allowedCertificate: Data?) -> Promise<WebDAVCredential> {
		// TODO: Add Input Validation
		guard let url = url, let username = username, let password = password, let baseURL = URL(string: url) else {
			return Promise(WebDAVAuthenticationError.invalidInput)
		}
		guard !username.isEmpty, !password.isEmpty else {
			return Promise(WebDAVAuthenticationError.invalidInput)
		}
		let credential = WebDAVCredential(baseURL: baseURL, username: username, password: password, allowedCertificate: allowedCertificate)
		return checkTLSCertificate(for: baseURL, allowedCertificate: allowedCertificate).then { _ -> Promise<Void> in
			let client = WebDAVClient(credential: credential)
			self.client = client
			return WebDAVAuthenticator.verifyClient(client: client)
		}.then { _ -> WebDAVCredential in
			self.client = nil
			try WebDAVAuthenticator.saveCredentialToKeychain(credential)
			return credential
		}
	}

	func checkTLSCertificate(for url: URL, allowedCertificate: Data?) -> Promise<Void> {
		guard allowedCertificate == nil else {
			return Promise(())
		}
		let validator = TLSCertificateValidator(baseURL: url)
		return validator.validate().then { certificate -> Void in
			guard certificate.isTrusted else {
				throw WebDAVAuthenticationError.untrustedCertificate(certificate: certificate, url: url)
			}
		}
	}
}
