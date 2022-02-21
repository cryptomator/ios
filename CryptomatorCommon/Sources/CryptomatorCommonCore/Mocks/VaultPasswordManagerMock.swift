//
//  VaultPasswordManagerMock.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 01.02.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

#if DEBUG
import Foundation
import LocalAuthentication

// swiftlint:disable all

final class VaultPasswordManagerMock: VaultPasswordManager {
	// MARK: - setPassword

	var setPasswordForVaultUIDThrowableError: Error?
	var setPasswordForVaultUIDCallsCount = 0
	var setPasswordForVaultUIDCalled: Bool {
		setPasswordForVaultUIDCallsCount > 0
	}

	var setPasswordForVaultUIDReceivedArguments: (password: String, vaultUID: String)?
	var setPasswordForVaultUIDReceivedInvocations: [(password: String, vaultUID: String)] = []
	var setPasswordForVaultUIDClosure: ((String, String) throws -> Void)?

	func setPassword(_ password: String, forVaultUID vaultUID: String) throws {
		if let error = setPasswordForVaultUIDThrowableError {
			throw error
		}
		setPasswordForVaultUIDCallsCount += 1
		setPasswordForVaultUIDReceivedArguments = (password: password, vaultUID: vaultUID)
		setPasswordForVaultUIDReceivedInvocations.append((password: password, vaultUID: vaultUID))
		try setPasswordForVaultUIDClosure?(password, vaultUID)
	}

	// MARK: - getPassword

	var getPasswordForVaultUIDContextThrowableError: Error?
	var getPasswordForVaultUIDContextCallsCount = 0
	var getPasswordForVaultUIDContextCalled: Bool {
		getPasswordForVaultUIDContextCallsCount > 0
	}

	var getPasswordForVaultUIDContextReceivedArguments: (vaultUID: String, context: LAContext)?
	var getPasswordForVaultUIDContextReceivedInvocations: [(vaultUID: String, context: LAContext)] = []
	var getPasswordForVaultUIDContextReturnValue: String!
	var getPasswordForVaultUIDContextClosure: ((String, LAContext) throws -> String)?

	func getPassword(forVaultUID vaultUID: String, context: LAContext) throws -> String {
		if let error = getPasswordForVaultUIDContextThrowableError {
			throw error
		}
		getPasswordForVaultUIDContextCallsCount += 1
		getPasswordForVaultUIDContextReceivedArguments = (vaultUID: vaultUID, context: context)
		getPasswordForVaultUIDContextReceivedInvocations.append((vaultUID: vaultUID, context: context))
		return try getPasswordForVaultUIDContextClosure.map({ try $0(vaultUID, context) }) ?? getPasswordForVaultUIDContextReturnValue
	}

	// MARK: - removePassword

	var removePasswordForVaultUIDThrowableError: Error?
	var removePasswordForVaultUIDCallsCount = 0
	var removePasswordForVaultUIDCalled: Bool {
		removePasswordForVaultUIDCallsCount > 0
	}

	var removePasswordForVaultUIDReceivedVaultUID: String?
	var removePasswordForVaultUIDReceivedInvocations: [String] = []
	var removePasswordForVaultUIDClosure: ((String) throws -> Void)?

	func removePassword(forVaultUID vaultUID: String) throws {
		if let error = removePasswordForVaultUIDThrowableError {
			throw error
		}
		removePasswordForVaultUIDCallsCount += 1
		removePasswordForVaultUIDReceivedVaultUID = vaultUID
		removePasswordForVaultUIDReceivedInvocations.append(vaultUID)
		try removePasswordForVaultUIDClosure?(vaultUID)
	}

	// MARK: - hasPassword

	var hasPasswordForVaultUIDThrowableError: Error?
	var hasPasswordForVaultUIDCallsCount = 0
	var hasPasswordForVaultUIDCalled: Bool {
		hasPasswordForVaultUIDCallsCount > 0
	}

	var hasPasswordForVaultUIDReceivedVaultUID: String?
	var hasPasswordForVaultUIDReceivedInvocations: [String] = []
	var hasPasswordForVaultUIDReturnValue: Bool!
	var hasPasswordForVaultUIDClosure: ((String) throws -> Bool)?

	func hasPassword(forVaultUID vaultUID: String) throws -> Bool {
		if let error = hasPasswordForVaultUIDThrowableError {
			throw error
		}
		hasPasswordForVaultUIDCallsCount += 1
		hasPasswordForVaultUIDReceivedVaultUID = vaultUID
		hasPasswordForVaultUIDReceivedInvocations.append(vaultUID)
		return try hasPasswordForVaultUIDClosure.map({ try $0(vaultUID) }) ?? hasPasswordForVaultUIDReturnValue
	}
}

// swiftlint:enable all
#endif
