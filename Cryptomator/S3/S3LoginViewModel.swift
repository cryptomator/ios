//
//  S3LoginViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 30.06.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import Combine
import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import Foundation

class S3LoginViewModel: ObservableObject {
	@Published var displayName = ""
	@Published var secretKey = ""
	@Published var accessKey = ""
	@Published var existingBucket = ""
	@Published var endpoint = "https://"
	@Published var region = ""
	@Published var loginState = S3LoginState.notLoggedIn {
		didSet {
			print("loginState changed to: \(loginState)")
		}
	}

	let title = "S3"

	lazy var saveDisabled: AnyPublisher<Bool, Never> = $secretKey.combineLatest($accessKey, $existingBucket, $endpoint).combineLatest($region, $displayName)
		.map {
			let (secretKey, accessKey, existingBucket, endpoint) = $0.0
			let region = $0.1
			let displayName = $0.2
			return secretKey.isEmpty || accessKey.isEmpty || existingBucket.isEmpty || endpoint.isEmpty || region.isEmpty || displayName.isEmpty
		}.eraseToAnyPublisher()

	let verifier: S3CredentialVerifierType
	let credentialManager: S3CredentialManagerType
	let credentialIdentifier: String

	init(displayName: String = "", credential: S3Credential? = nil, verifier: S3CredentialVerifierType = S3CredentialVerifier.shared, credentialManager: S3CredentialManagerType = S3CredentialManager.shared) {
		self.verifier = verifier
		self.credentialManager = credentialManager
		self.displayName = displayName
		if let credential = credential {
			self.secretKey = credential.secretKey
			self.accessKey = credential.accessKey
			self.existingBucket = credential.bucket
			self.endpoint = credential.url.absoluteString
			self.region = credential.region
			self.credentialIdentifier = credential.identifier
		} else {
			self.credentialIdentifier = UUID().uuidString
		}
	}

	func saveS3Credential() {
		guard !secretKey.isEmpty, !accessKey.isEmpty, !existingBucket.isEmpty, !endpoint.isEmpty, !region.isEmpty, !displayName.isEmpty else {
			loginState = .error(S3LoginViewModelError.emptyField)
			return
		}
		guard let url = URL(string: endpoint) else {
			loginState = .error(S3LoginViewModelError.invalidEndpoint)
			return
		}
		let credential = S3Credential(accessKey: accessKey,
		                              secretKey: secretKey,
		                              url: url,
		                              bucket: existingBucket,
		                              region: region,
		                              identifier: credentialIdentifier)
		loginState = .verifyingCredentials
		verifier.verifyCredential(credential).then {
			try self.credentialManager.save(credential: credential, displayName: self.displayName)
			self.loginState = .loggedIn(credential)
		}.catch {
			self.handleError($0)
		}
	}

	private func handleError(_ error: Error) {
		let convertedError: Error
		switch error {
		case LocalizedCloudProviderError.unauthorized, CloudProviderError.unauthorized:
			convertedError = S3LoginViewModelError.invalidCredentials
		default:
			convertedError = error
		}
		loginState = .error(convertedError)
	}
}

enum S3LoginState {
	case error(Error)
	case verifyingCredentials
	case loggedIn(S3Credential)
	case notLoggedIn
}

enum S3LoginViewModelError: Error {
	case emptyField
	case invalidEndpoint
	case invalidCredentials
}

extension S3LoginViewModelError: LocalizedError {
	var errorDescription: String? {
		switch self {
		case .emptyField:
			return nil
		case .invalidEndpoint:
			return LocalizedString.getValue("s3Login.error.invalidEndpoint")
		case .invalidCredentials:
			return LocalizedString.getValue("s3Login.error.invalidCredentials")
		}
	}
}
