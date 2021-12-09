//
//  WebDAVAuthenticationViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 07.04.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Combine
import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import Foundation
import Promises

enum WebDAVAuthenticationError: Error {
	case invalidInput
	case untrustedCertificate(certificate: TLSCertificate, url: URL)
	case userCanceled
	case httpConnection
}

protocol WebDAVAuthenticationViewModelProtocol: SingleSectionTableViewModel, ReturnButtonSupport {
	func createWebDAVCredentialFromInput(allowedCertificate: Data?, allowHTTPConnection: Bool) throws -> WebDAVCredential
	func addAccount(credential: WebDAVCredential) -> Promise<WebDAVCredential>
	func transformURLToHTTPS() throws
}

class WebDAVAuthenticationViewModel: SingleSectionTableViewModel, WebDAVAuthenticationViewModelProtocol {
	var lastReturnButtonPressed: AnyPublisher<Void, Never> {
		return setupReturnButtonSupport(for: [urlCellViewModel, usernameCellViewModel, passwordCellViewModel], subscribers: &subscribers)
	}

	override var cells: [TableViewCellViewModel] {
		[
			urlCellViewModel,
			usernameCellViewModel,
			passwordCellViewModel
		]
	}

	let urlCellViewModel = TextFieldCellViewModel(type: .url, text: "https://", placeholder: LocalizedString.getValue("common.cells.url"), isInitialFirstResponder: true)
	let usernameCellViewModel = TextFieldCellViewModel(type: .username, placeholder: LocalizedString.getValue("common.cells.username"))
	let passwordCellViewModel = TextFieldCellViewModel(type: .password, placeholder: LocalizedString.getValue("common.cells.password"))

	var url: String {
		get {
			return urlCellViewModel.input.value
		}
		set {
			urlCellViewModel.input.value = newValue
		}
	}

	var username: String {
		return usernameCellViewModel.input.value
	}

	var password: String {
		return passwordCellViewModel.input.value
	}

	private var client: WebDAVClient?
	private lazy var subscribers = Set<AnyCancellable>()

	func createWebDAVCredentialFromInput(allowedCertificate: Data?, allowHTTPConnection: Bool = false) throws -> WebDAVCredential {
		guard let baseURL = URL(string: url) else {
			throw WebDAVAuthenticationError.invalidInput
		}
		if !allowHTTPConnection, baseURL.scheme == "http" {
			throw WebDAVAuthenticationError.httpConnection
		}
		guard !username.isEmpty, !password.isEmpty else {
			throw WebDAVAuthenticationError.invalidInput
		}
		return WebDAVCredential(baseURL: baseURL, username: username, password: password, allowedCertificate: allowedCertificate)
	}

	func transformURLToHTTPS() throws {
		var components = URLComponents(string: url)
		components?.scheme = "https"
		guard let transformedURL = components?.string else {
			throw WebDAVAuthenticationError.invalidInput
		}
		url = transformedURL
	}

	func addAccount(credential: WebDAVCredential) -> Promise<WebDAVCredential> {
		let checkTLSCertificatePromise: Promise<Void>
		if credential.baseURL.scheme == "http" {
			checkTLSCertificatePromise = Promise(())
		} else {
			checkTLSCertificatePromise = checkTLSCertificate(for: credential.baseURL, allowedCertificate: credential.allowedCertificate)
		}
		return checkTLSCertificatePromise.then { _ -> Promise<Void> in
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
