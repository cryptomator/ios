//
//  File 2.swift
//
//
//  Created by Philipp Schmid on 22.07.22.
//

import AppAuthCore
import CryptoKit
import CryptomatorCloudAccessCore
import Foundation
import JOSESwift

public enum AddHubVaultViewModelError: Error {
	case missingHubConfig
	case missingAuthState
}

public enum AddHubVaultViewModelState {
	case detectedVault
	case receivedExistingKey
	case accessNotGranted
	case deviceRegisteredSuccessfully
	case needsDeviceRegistration
	case loading(text: String)
}

open class HubVaultViewModel: ObservableObject {
	public var authState: OIDAuthState?
	@Published public var state: AddHubVaultViewModelState
	@Published public var deviceName: String = ""
	@Published public var error: Error?
	public weak var coordinator: HubVaultCoordinator?
	let vaultConfig: UnverifiedVaultConfig
	let deviceRegisteringService: HubDeviceRegistering
	let hubKeyService: HubKeyReceiving

	public init(initialState: AddHubVaultViewModelState, vaultConfig: UnverifiedVaultConfig, deviceRegisteringService: HubDeviceRegistering = CryptomatorHubAuthenticator.shared, hubKeyService: HubKeyReceiving = CryptomatorHubAuthenticator.shared, coordinator: HubVaultCoordinator? = nil) {
		self.state = initialState
		self.vaultConfig = vaultConfig
		self.deviceRegisteringService = deviceRegisteringService
		self.hubKeyService = hubKeyService
		self.coordinator = coordinator
	}

	public func register() async {
		await setError(to: nil)
		guard let hubConfig = vaultConfig.hub else {
			error = AddHubVaultViewModelError.missingHubConfig
			return
		}
		guard let authState = authState else {
			error = AddHubVaultViewModelError.missingAuthState
			return
		}

		do {
			try await deviceRegisteringService.registerDevice(withName: deviceName, hubConfig: hubConfig, authState: authState)
		} catch {
			await setError(to: error)
			return
		}
		await setState(to: .deviceRegisteredSuccessfully)
	}

	public func continueToAccessCheck() async {
		await setError(to: nil)
		guard let authState = authState else {
			await setError(to: AddHubVaultViewModelError.missingAuthState)
			return
		}
		await setState(to: .loading(text: "Cryptomator is receiving and processing the response from Hub. Please wait."))

		let authFlow: HubAuthenticationFlow
		do {
			authFlow = try await hubKeyService.receiveKey(authState: authState, vaultConfig: vaultConfig)
		} catch {
			await setError(to: error)
			return
		}
		switch authFlow {
		case let .receivedExistingKey(data):
			await receivedExistingKey(data: data)
		case .accessNotGranted:
			await setState(to: .accessNotGranted)
		case .needsDeviceRegistration:
			await setState(to: .needsDeviceRegistration)
		}
	}

	public func refresh() async {
		await continueToAccessCheck()
	}

	public func receivedExistingKey(data: Data) async {
		let privateKey: P384.KeyAgreement.PrivateKey
		let jwe: JWE
		let hubAccount: HubAccount
		do {
			privateKey = try CryptomatorHubKeyProvider.shared.getPrivateKey()
			jwe = try JWE(compactSerialization: data)
			hubAccount = try HubAccount(authState: authState!)
			try HubAccountManager.shared.saveHubAccount(hubAccount)
		} catch {
			await setError(to: error)
			return
		}
		await receivedExistingKey(jwe: jwe, privateKey: privateKey, hubAccount: hubAccount)
	}

	open func receivedExistingKey(jwe: JWE, privateKey: P384.KeyAgreement.PrivateKey, hubAccount: HubAccount) async {
		fatalError("Abstract method receivedExistingKey(jwe:privateKey:hubAccount:) not implemented")
	}

	@MainActor
	public func setState(to newState: AddHubVaultViewModelState) {
		state = newState
	}

	@MainActor
	public func setError(to newError: Error?) {
		error = newError
	}
}
