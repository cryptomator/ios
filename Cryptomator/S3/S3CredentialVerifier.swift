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
import Promises

protocol S3CredentialVerifierType {
	func verifyCredential(_ credential: S3Credential) -> Promise<Void>
}

struct S3CredentialVerifier: S3CredentialVerifierType {
	static let shared = S3CredentialVerifier()
	private init() {}
	func verifyCredential(_ credential: S3Credential) -> Promise<Void> {
		return S3Authenticator.verifyCredential(credential).recover { error -> Void in
			switch error {
			case let cloudProviderError as CloudProviderError:
				throw LocalizedCloudProviderError.convertToLocalized(cloudProviderError, cloudPath: .init("/"))
			default:
				throw error
			}
		}
	}
}
