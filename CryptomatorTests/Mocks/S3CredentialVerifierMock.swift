//
//  S3CredentialVerifierMock.swift
//  CryptomatorTests
//
//  Created by Philipp Schmid on 30.06.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation
import Promises
@testable import Cryptomator

final class S3CredentialVerifierTypeMock: S3CredentialVerifierType {
	// MARK: - verifyCredential

	var verifyCredentialThrowableError: Error?
	var verifyCredentialCallsCount = 0
	var verifyCredentialCalled: Bool {
		verifyCredentialCallsCount > 0
	}

	var verifyCredentialReceivedCredential: S3Credential?
	var verifyCredentialReceivedInvocations: [S3Credential] = []
	var verifyCredentialReturnValue: Promise<Void>!
	var verifyCredentialClosure: ((S3Credential) -> Promise<Void>)?

	func verifyCredential(_ credential: S3Credential) -> Promise<Void> {
		if let error = verifyCredentialThrowableError {
			return Promise(error)
		}
		verifyCredentialCallsCount += 1
		verifyCredentialReceivedCredential = credential
		verifyCredentialReceivedInvocations.append(credential)
		return verifyCredentialClosure.map({ $0(credential) }) ?? verifyCredentialReturnValue
	}
}
