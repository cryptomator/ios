//
//  WebDAVCredentialManagerMock.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 28.08.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

#if DEBUG
import Combine
import CryptomatorCloudAccessCore
import Foundation

// swiftlint:disable all

final class WebDAVCredentialManagerMock: WebDAVCredentialManaging {
	var didUpdate: AnyPublisher<Void, Never> { didUpdatePublisher.eraseToAnyPublisher() }

	var didUpdatePublisher = PassthroughSubject<Void, Never>()

	// MARK: - getCredentialFromKeychain

	var getCredentialFromKeychainWithCallsCount = 0
	var getCredentialFromKeychainWithCalled: Bool {
		getCredentialFromKeychainWithCallsCount > 0
	}

	var getCredentialFromKeychainWithReceivedAccountUID: String?
	var getCredentialFromKeychainWithReceivedInvocations: [String] = []
	var getCredentialFromKeychainWithReturnValue: WebDAVCredential?
	var getCredentialFromKeychainWithClosure: ((String) -> WebDAVCredential?)?

	func getCredentialFromKeychain(with accountUID: String) -> WebDAVCredential? {
		getCredentialFromKeychainWithCallsCount += 1
		getCredentialFromKeychainWithReceivedAccountUID = accountUID
		getCredentialFromKeychainWithReceivedInvocations.append(accountUID)
		return getCredentialFromKeychainWithClosure.map({ $0(accountUID) }) ?? getCredentialFromKeychainWithReturnValue
	}

	// MARK: - saveCredentialToKeychain

	var saveCredentialToKeychainThrowableError: Error?
	var saveCredentialToKeychainCallsCount = 0
	var saveCredentialToKeychainCalled: Bool {
		saveCredentialToKeychainCallsCount > 0
	}

	var saveCredentialToKeychainReceivedCredential: WebDAVCredential?
	var saveCredentialToKeychainReceivedInvocations: [WebDAVCredential] = []
	var saveCredentialToKeychainClosure: ((WebDAVCredential) throws -> Void)?

	func saveCredentialToKeychain(_ credential: WebDAVCredential) throws {
		if let error = saveCredentialToKeychainThrowableError {
			throw error
		}
		saveCredentialToKeychainCallsCount += 1
		saveCredentialToKeychainReceivedCredential = credential
		saveCredentialToKeychainReceivedInvocations.append(credential)
		try saveCredentialToKeychainClosure?(credential)
	}

	// MARK: - removeCredentialFromKeychain

	var removeCredentialFromKeychainWithThrowableError: Error?
	var removeCredentialFromKeychainWithCallsCount = 0
	var removeCredentialFromKeychainWithCalled: Bool {
		removeCredentialFromKeychainWithCallsCount > 0
	}

	var removeCredentialFromKeychainWithReceivedAccountUID: String?
	var removeCredentialFromKeychainWithReceivedInvocations: [String] = []
	var removeCredentialFromKeychainWithClosure: ((String) throws -> Void)?

	func removeCredentialFromKeychain(with accountUID: String) throws {
		if let error = removeCredentialFromKeychainWithThrowableError {
			throw error
		}
		removeCredentialFromKeychainWithCallsCount += 1
		removeCredentialFromKeychainWithReceivedAccountUID = accountUID
		removeCredentialFromKeychainWithReceivedInvocations.append(accountUID)
		try removeCredentialFromKeychainWithClosure?(accountUID)
	}

	// MARK: - removeUnusedWebDAVCredentials

	var removeUnusedWebDAVCredentialsExistingAccountUIDsThrowableError: Error?
	var removeUnusedWebDAVCredentialsExistingAccountUIDsCallsCount = 0
	var removeUnusedWebDAVCredentialsExistingAccountUIDsCalled: Bool {
		removeUnusedWebDAVCredentialsExistingAccountUIDsCallsCount > 0
	}

	var removeUnusedWebDAVCredentialsExistingAccountUIDsReceivedExistingAccountUIDs: [String]?
	var removeUnusedWebDAVCredentialsExistingAccountUIDsReceivedInvocations: [[String]] = []
	var removeUnusedWebDAVCredentialsExistingAccountUIDsClosure: (([String]) throws -> Void)?

	func removeUnusedWebDAVCredentials(existingAccountUIDs: [String]) throws {
		if let error = removeUnusedWebDAVCredentialsExistingAccountUIDsThrowableError {
			throw error
		}
		removeUnusedWebDAVCredentialsExistingAccountUIDsCallsCount += 1
		removeUnusedWebDAVCredentialsExistingAccountUIDsReceivedExistingAccountUIDs = existingAccountUIDs
		removeUnusedWebDAVCredentialsExistingAccountUIDsReceivedInvocations.append(existingAccountUIDs)
		try removeUnusedWebDAVCredentialsExistingAccountUIDsClosure?(existingAccountUIDs)
	}
}

// swiftlint:enable all
#endif
