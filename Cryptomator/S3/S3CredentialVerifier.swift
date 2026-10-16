//
//  S3CredentialVerifier.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 29.06.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import Foundation

protocol S3CredentialVerifierType {
	func verifyCredential(_ credential: S3Credential) async throws
}

struct S3CredentialVerifier: S3CredentialVerifierType {
	static let shared = S3CredentialVerifier()
	private init() {}
	func verifyCredential(_ credential: S3Credential) async throws {
		do {
			try await S3Authenticator.verifyCredential(credential)
		} catch let cloudProviderError as CloudProviderError {
			throw LocalizedCloudProviderError.convertToLocalized(cloudProviderError, cloudPath: .init("/"))
		}
	}
}
