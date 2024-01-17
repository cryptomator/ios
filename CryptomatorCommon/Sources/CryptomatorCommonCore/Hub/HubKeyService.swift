//
//  HubKeyService.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 19.11.23.
//  Copyright © 2023 Skymatic GmbH. All rights reserved.
//

import AppAuthCore
import CryptomatorCloudAccessCore
import Dependencies
import Foundation

public protocol HubKeyReceiving {
	func receiveKey(authState: OIDAuthState, vaultConfig: UnverifiedVaultConfig) async throws -> HubAuthenticationFlow
}

private enum HubKeyReceivingDependencyKey: DependencyKey {
	static let liveValue: HubKeyReceiving = CryptomatorHubAuthenticator()
	#if DEBUG
	static let testValue: HubKeyReceiving = UnimplementedHubKeyReceivingService()
	#endif
}

extension DependencyValues {
	var hubKeyService: HubKeyReceiving {
		get { self[HubKeyReceivingDependencyKey.self] }
		set { self[HubKeyReceivingDependencyKey.self] = newValue }
	}
}

#if DEBUG
final class UnimplementedHubKeyReceivingService: HubKeyReceiving {
	func receiveKey(authState: OIDAuthState, vaultConfig: UnverifiedVaultConfig) async throws -> HubAuthenticationFlow {
		unimplemented(placeholder: .accessNotGranted)
	}
}

// MARK: - HubKeyReceivingMock -

final class HubKeyReceivingMock: HubKeyReceiving {
	// MARK: - receiveKey

	var receiveKeyAuthStateVaultConfigThrowableError: Error?
	var receiveKeyAuthStateVaultConfigCallsCount = 0
	var receiveKeyAuthStateVaultConfigCalled: Bool {
		receiveKeyAuthStateVaultConfigCallsCount > 0
	}

	var receiveKeyAuthStateVaultConfigReceivedArguments: (authState: OIDAuthState, vaultConfig: UnverifiedVaultConfig)?
	var receiveKeyAuthStateVaultConfigReceivedInvocations: [(authState: OIDAuthState, vaultConfig: UnverifiedVaultConfig)] = []
	var receiveKeyAuthStateVaultConfigReturnValue: HubAuthenticationFlow!
	var receiveKeyAuthStateVaultConfigClosure: ((OIDAuthState, UnverifiedVaultConfig) throws -> HubAuthenticationFlow)?

	func receiveKey(authState: OIDAuthState, vaultConfig: UnverifiedVaultConfig) throws -> HubAuthenticationFlow {
		if let error = receiveKeyAuthStateVaultConfigThrowableError {
			throw error
		}
		receiveKeyAuthStateVaultConfigCallsCount += 1
		receiveKeyAuthStateVaultConfigReceivedArguments = (authState: authState, vaultConfig: vaultConfig)
		receiveKeyAuthStateVaultConfigReceivedInvocations.append((authState: authState, vaultConfig: vaultConfig))
		return try receiveKeyAuthStateVaultConfigClosure.map({ try $0(authState, vaultConfig) }) ?? receiveKeyAuthStateVaultConfigReturnValue
	}
}
#endif
