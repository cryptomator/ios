//
//  S3CredentialManagerMock.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 30.06.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

#if DEBUG
import CryptomatorCloudAccessCore
import Foundation

// swiftlint:disable all
final class S3CredentialManagerTypeMock: S3CredentialManagerType {
	// MARK: - save

	var saveCredentialDisplayNameThrowableError: Error?
	var saveCredentialDisplayNameCallsCount = 0
	var saveCredentialDisplayNameCalled: Bool {
		saveCredentialDisplayNameCallsCount > 0
	}

	var saveCredentialDisplayNameReceivedArguments: (credential: S3Credential, displayName: String)?
	var saveCredentialDisplayNameReceivedInvocations: [(credential: S3Credential, displayName: String)] = []
	var saveCredentialDisplayNameClosure: ((S3Credential, String) throws -> Void)?

	func save(credential: S3Credential, displayName: String) throws {
		if let error = saveCredentialDisplayNameThrowableError {
			throw error
		}
		saveCredentialDisplayNameCallsCount += 1
		saveCredentialDisplayNameReceivedArguments = (credential: credential, displayName: displayName)
		saveCredentialDisplayNameReceivedInvocations.append((credential: credential, displayName: displayName))
		try saveCredentialDisplayNameClosure?(credential, displayName)
	}

	// MARK: - removeCredential

	var removeCredentialWithThrowableError: Error?
	var removeCredentialWithCallsCount = 0
	var removeCredentialWithCalled: Bool {
		removeCredentialWithCallsCount > 0
	}

	var removeCredentialWithReceivedIdentifier: String?
	var removeCredentialWithReceivedInvocations: [String] = []
	var removeCredentialWithClosure: ((String) throws -> Void)?

	func removeCredential(with identifier: String) throws {
		if let error = removeCredentialWithThrowableError {
			throw error
		}
		removeCredentialWithCallsCount += 1
		removeCredentialWithReceivedIdentifier = identifier
		removeCredentialWithReceivedInvocations.append(identifier)
		try removeCredentialWithClosure?(identifier)
	}

	// MARK: - getDisplayName

	var getDisplayNameForThrowableError: Error?
	var getDisplayNameForCallsCount = 0
	var getDisplayNameForCalled: Bool {
		getDisplayNameForCallsCount > 0
	}

	var getDisplayNameForReceivedIdentifier: String?
	var getDisplayNameForReceivedInvocations: [String] = []
	var getDisplayNameForReturnValue: String?
	var getDisplayNameForClosure: ((String) throws -> String?)?

	func getDisplayName(for identifier: String) throws -> String? {
		if let error = getDisplayNameForThrowableError {
			throw error
		}
		getDisplayNameForCallsCount += 1
		getDisplayNameForReceivedIdentifier = identifier
		getDisplayNameForReceivedInvocations.append(identifier)
		return try getDisplayNameForClosure.map({ try $0(identifier) }) ?? getDisplayNameForReturnValue
	}

	// MARK: - getCredential

	var getCredentialWithCallsCount = 0
	var getCredentialWithCalled: Bool {
		getCredentialWithCallsCount > 0
	}

	var getCredentialWithReceivedIdentifier: String?
	var getCredentialWithReceivedInvocations: [String] = []
	var getCredentialWithReturnValue: S3Credential?
	var getCredentialWithClosure: ((String) -> S3Credential?)?

	func getCredential(with identifier: String) -> S3Credential? {
		getCredentialWithCallsCount += 1
		getCredentialWithReceivedIdentifier = identifier
		getCredentialWithReceivedInvocations.append(identifier)
		return getCredentialWithClosure.map({ $0(identifier) }) ?? getCredentialWithReturnValue
	}
}

// swiftlint:enable all
#endif
