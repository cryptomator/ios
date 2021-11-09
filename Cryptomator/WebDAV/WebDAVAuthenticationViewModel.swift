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
	func createWebDAVCredentialFromInput(url: String?, username: String?, password: String?, allowedCertificate: Data?) throws -> WebDAVCredential
	func addAccount(credential: WebDAVCredential) -> Promise<WebDAVCredential>
}

class WebDAVAuthenticationViewModel: WebDAVAuthenticationViewModelProtocol {
	private var client: WebDAVClient?

	func createWebDAVCredentialFromInput(url: String?, username: String?, password: String?, allowedCertificate: Data?) throws -> WebDAVCredential {
		// TODO: Add Input Validation
		guard let url = url, let username = username, let password = password, let baseURL = URL(string: url) else {
			throw WebDAVAuthenticationError.invalidInput
		}
		guard !username.isEmpty, !password.isEmpty else {
			throw WebDAVAuthenticationError.invalidInput
		}
		return WebDAVCredential(baseURL: baseURL, username: username, password: password, allowedCertificate: allowedCertificate)
	}

	func addAccount(credential: WebDAVCredential) -> Promise<WebDAVCredential> {
		return checkTLSCertificate(for: credential.baseURL, allowedCertificate: credential.allowedCertificate).then { _ -> Promise<Void> in
			let client = WebDAVClient(credential: credential)
			self.client = client
			return WebDAVAuthenticator.verifyClient(client: client)
		}.then { _ -> WebDAVCredential in
			self.client = nil
			try WebDAVAuthenticator.saveCredentialToKeychain(credential)
			return credential
		}.recover { error -> WebDAVCredential in
			guard case let WebDAVAuthenticatorKeychainError.credentialDuplicate(identifier) = error else {
				throw error
			}
			let updatedCredential = WebDAVCredential(baseURL: credential.baseURL,
			                                         username: credential.username,
			                                         password: credential.password,
			                                         allowedCertificate: credential.allowedCertificate,
			                                         identifier: identifier)
			try WebDAVAuthenticator.saveCredentialToKeychain(updatedCredential)
			return updatedCredential
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
