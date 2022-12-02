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

class WebDAVAuthenticationViewModel: ObservableObject {
	@Published var url: String {
		willSet {
			if url != newValue {
				allowedCertificate = nil
			}
		}
	}

	@Published var username: String
	@Published var password: String
	@Published var state: State = .initial

	lazy var saveButtonIsEnabled: AnyPublisher<Bool, Never> = $url.combineLatest($username, $password).map { url, username, password in
		let validURL = URL(string: url) != nil
		return validURL && !username.isEmpty && !password.isEmpty
	}.eraseToAnyPublisher()

	var showUntrustedCertificateError: Bool {
		get {
			switch state {
			case .untrustedCertificate:
				return true
			default:
				return false
			}
		}
		set {
			if !newValue {
				state = .initial
			}
		}
	}

	var showAllowInsecureConnectionAlert: Bool {
		get {
			if case State.insecureConnectionNotAllowed = state {
				return true
			} else {
				return false
			}
		}
		set {
			if !newValue {
				state = .initial
			}
		}
	}

	var verifyClient: (WebDAVClient) -> Promise<Void> = WebDAVAuthenticator.verifyClient(client:)

	private var allowedCertificate: Data?
	private var allowHTTPConnection: Bool

	private let credentialManager: WebDAVCredentialManaging
	private let validationHelper: TLSCertificateValidationHelping
	private let identifier: String
	private let cloudProviderUpdating: CloudProviderUpdating
	private var client: WebDAVClient?

	convenience init(credentialManager: WebDAVCredentialManaging = WebDAVCredentialManager.shared,
	                 validationHelper: TLSCertificateValidationHelping = TLSCertificateValidationHelper(),
	                 cloudProviderUpdating: CloudProviderUpdating = CloudProviderDBManager.shared) {
		self.init(url: "https://",
		          username: "",
		          password: "",
		          allowedCertificate: nil,
		          allowHTTPConnection: false,
		          identifier: UUID().uuidString,
		          credentialManager: credentialManager,
		          validationHelper: validationHelper,
		          cloudProviderUpdating: cloudProviderUpdating)
	}

	convenience init(credential: WebDAVCredential,
	                 credentialManager: WebDAVCredentialManaging = WebDAVCredentialManager.shared,
	                 validationHelper: TLSCertificateValidationHelping = TLSCertificateValidationHelper(),
	                 cloudProviderUpdating: CloudProviderUpdating = CloudProviderDBManager.shared) {
		let components = URLComponents(url: credential.baseURL, resolvingAgainstBaseURL: false)
		let allowHttpConnection = components?.scheme == "http"
		self.init(url: credential.baseURL.absoluteString,
		          username: credential.username,
		          password: credential.password,
		          allowedCertificate: credential.allowedCertificate,
		          allowHTTPConnection: allowHttpConnection,
		          identifier: credential.identifier,
		          credentialManager: credentialManager,
		          validationHelper: validationHelper,
		          cloudProviderUpdating: cloudProviderUpdating)
	}

	private init(url: String,
	             username: String,
	             password: String,
	             allowedCertificate: Data?,
	             allowHTTPConnection: Bool,
	             identifier: String,
	             credentialManager: WebDAVCredentialManaging,
	             validationHelper: TLSCertificateValidationHelping,
	             cloudProviderUpdating: CloudProviderUpdating) {
		self.url = url
		self.username = username
		self.password = password
		self.allowedCertificate = allowedCertificate
		self.allowHTTPConnection = allowHTTPConnection
		self.identifier = identifier
		self.credentialManager = credentialManager
		self.validationHelper = validationHelper
		self.cloudProviderUpdating = cloudProviderUpdating
	}

	func saveAccount() {
		guard let credential = createWebDAVCredentialFromInput() else {
			return
		}
		state = .authenticating
		addAccount(credential: credential).then {
			self.state = .authenticated($0)
			self.cloudProviderUpdating.providerShouldUpdate(with: self.identifier)
		}.catch { error in
			switch error {
			case let WebDAVAuthenticationError.untrustedCertificate(certificate, url):
				self.state = .untrustedCertificate(certificate: certificate, url: url)
			default:
				self.state = .error(error)
			}
		}
	}

	func saveAccountWithCertificate() {
		allowCertificate()
		saveAccount()
	}

	func allowCertificate() {
		guard case State.untrustedCertificate(certificate: let certificate, url: _) = state else {
			return
		}
		allowedCertificate = certificate.data
	}

	func saveAccountWithTransformedURL() {
		do {
			try transformURLToHTTPS()
		} catch {
			state = .error(error)
			return
		}
		saveAccount()
	}

	func saveAccountWithInsecureConnection() {
		allowHTTPConnection = true
		saveAccount()
	}

	private func createWebDAVCredentialFromInput() -> WebDAVCredential? {
		guard let baseURL = URL(string: url) else {
			state = .error(WebDAVAuthenticationError.invalidInput)
			return nil
		}
		if !allowHTTPConnection, baseURL.scheme == "http" {
			state = .insecureConnectionNotAllowed
			return nil
		}
		guard !username.isEmpty, !password.isEmpty else {
			state = .error(WebDAVAuthenticationError.invalidInput)
			return nil
		}
		return WebDAVCredential(baseURL: baseURL, username: username, password: password, allowedCertificate: allowedCertificate, identifier: identifier)
	}

	private func addAccount(credential: WebDAVCredential) -> Promise<WebDAVCredential> {
		let checkTLSCertificatePromise: Promise<Void>
		if credential.baseURL.scheme == "http" {
			checkTLSCertificatePromise = Promise(())
		} else {
			checkTLSCertificatePromise = checkTLSCertificate(for: credential.baseURL, allowedCertificate: credential.allowedCertificate)
		}
		return checkTLSCertificatePromise.then { _ -> Promise<Void> in
			let client = WebDAVClient(credential: credential)
			self.client = client
			return self.verifyClient(client)
		}.then { _ -> WebDAVCredential in
			self.client = nil
			try self.credentialManager.saveCredentialToKeychain(credential)
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
			try self.credentialManager.saveCredentialToKeychain(updatedCredential)
			return updatedCredential
		}
	}

	private func transformURLToHTTPS() throws {
		var components = URLComponents(string: url)
		components?.scheme = "https"
		guard let transformedURL = components?.string else {
			throw WebDAVAuthenticationError.invalidInput
		}
		url = transformedURL
	}

	private func checkTLSCertificate(for url: URL, allowedCertificate: Data?) -> Promise<Void> {
		guard allowedCertificate == nil else {
			return Promise(())
		}
		return validationHelper.validate(url: url).then { certificate -> Void in
			guard certificate.isTrusted else {
				throw WebDAVAuthenticationError.untrustedCertificate(certificate: certificate, url: url)
			}
		}
	}

	enum State {
		case initial
		case authenticating
		case untrustedCertificate(certificate: TLSCertificate, url: URL)
		case insecureConnectionNotAllowed
		case error(Error)
		case authenticated(WebDAVCredential)
	}
}
