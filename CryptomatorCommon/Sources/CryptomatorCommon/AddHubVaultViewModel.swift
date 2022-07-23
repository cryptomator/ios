//
//  AddHubVaultViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 21.07.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import AppAuthCore
import CryptoKit
import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import CryptomatorCryptoLib
import FileProvider
import Foundation
import JOSESwift
import Promises

class AddHubVaultViewModel: HubVaultViewModel, HubVaultAdding {
	let downloadedVaultConfig: DownloadedVaultConfig
	let vaultItem: VaultItem
	let vaultManager: VaultManager
	let delegateAccountUID: String
	let vaultUID: String
	private weak var addHubVaultCoordinator: AddHubVaultCoordinator?

	init(downloadedVaultConfig: DownloadedVaultConfig, vaultItem: VaultItem, vaultUID: String, delegateAccountUID: String, vaultManager: VaultManager = VaultDBManager.shared, coordinator: (HubVaultCoordinator & AddHubVaultCoordinator)? = nil) {
		self.downloadedVaultConfig = downloadedVaultConfig
		self.vaultItem = vaultItem
		self.vaultUID = vaultUID
		self.delegateAccountUID = delegateAccountUID
		self.vaultManager = vaultManager
		self.addHubVaultCoordinator = coordinator
		super.init(initialState: .detectedVault, vaultConfig: downloadedVaultConfig.vaultConfig, coordinator: coordinator)
	}

	func login() {
		error = nil
		let vaultConfig = downloadedVaultConfig.vaultConfig
		guard let hubConfig = vaultConfig.hub else {
			error = AddHubVaultViewModelError.missingHubConfig
			return
		}
		Task {
			do {
				guard let authState = try await addHubVaultCoordinator?.authenticate(with: hubConfig) else {
					setError(to: AddHubVaultViewModelError.missingAuthState)
					return
				}
				self.authState = authState
				continueToAccessCheck()
			} catch {
				setError(to: error)
			}
		}
	}

	override func receivedExistingKey(jwe: JWE, privateKey: P384.KeyAgreement.PrivateKey, hubAccount: HubAccount) {
		addVault(jwe: jwe, privateKey: privateKey, hubAccount: hubAccount)
	}

	private func addVault(jwe: JWE, privateKey: P384.KeyAgreement.PrivateKey, hubAccount: HubAccount) {
		vaultManager.addExistingHubVault(vaultUID: vaultUID,
		                                 delegateAccountUID: delegateAccountUID,
		                                 hubUserID: hubAccount.userID,
		                                 jweData: jwe.compactSerializedData,
		                                 privateKey: privateKey,
		                                 vaultItem: vaultItem,
		                                 downloadedVaultConfig: downloadedVaultConfig).then {
			self.addHubVaultCoordinator?.addedVault(withName: self.vaultItem.name, vaultUID: self.vaultUID)
		}.catch { error in
			self.setError(to: error)
		}
	}
}

/*
 public class HubVaultViewModel: ObservableObject {
 	fileprivate(set) var authState: OIDAuthState?
 	@Published var state: AddHubVaultViewModelState
 	@Published var deviceName: String = ""
 	@Published var error: Error?
 	weak var coordinator: HubVaultCoordinator?
 	let vaultConfig: UnverifiedVaultConfig

 	init(initialState: AddHubVaultViewModelState, vaultConfig: UnverifiedVaultConfig, coordinator: HubVaultCoordinator? = nil) {
 		self.state = initialState
 		self.vaultConfig = vaultConfig
 		self.coordinator = coordinator
 	}

 	func register() {
 		error = nil
 		guard let hubConfig = vaultConfig.hub else {
 			error = AddHubVaultViewModelError.missingHubConfig
 			return
 		}
 		guard let authState = authState else {
 			error = AddHubVaultViewModelError.missingAuthState
 			return
 		}

 		Task {
 			do {
 				try await CryptomatorHubAuthenticator.registerDevice(withName: deviceName, hubConfig: hubConfig, authState: authState)
 			} catch {
 				setError(to: error)
 				return
 			}
 			setState(to: .deviceRegisteredSuccessfully)
 		}
 	}

 	func continueToAccessCheck() {
 		setError(to: nil)
 		guard let authState = authState else {
 			setError(to: AddHubVaultViewModelError.missingAuthState)
 			return
 		}
 		setState(to: .loading(text: "Cryptomator is receiving and processing the response from Hub. Please wait."))
 		Task {
 			let authFlow: HubAuthenticationFlow
 			do {
 				authFlow = try await CryptomatorHubAuthenticator.receiveKey(authState: authState, vaultConfig: vaultConfig)
 			} catch {
 				setError(to: error)
 				return
 			}
 			switch authFlow {
 			case .receivedExistingKey(let data):
 				receivedExistingKey(data: data)
 			case .accessNotGranted:
 				setState(to: .accessNotGranted)
 			case .needsDeviceRegistration:
 				setState(to: .needsDeviceRegistration)
 			}
 		}
 	}

 	func refresh() {
 		continueToAccessCheck()
 	}

 	func receivedExistingKey(data: Data) {
 		let privateKey: P384.KeyAgreement.PrivateKey
 		let jwe: JWE
 		let hubAccount: HubAccount
 		do {
 			privateKey = try CryptomatorHubKeyProvider.shared.getPrivateKey()
 			jwe = try JWE(compactSerialization: data)
 			hubAccount = try HubAccount(authState: authState!)
 			try HubAccountManager.shared.saveHubAccount(hubAccount)
 		} catch {
 			setError(to: error)
 			return
 		}
 		receivedExistingKey(jwe: jwe, privateKey: privateKey, hubAccount: hubAccount)
 	}

 	func receivedExistingKey(jwe: JWE, privateKey: P384.KeyAgreement.PrivateKey, hubAccount: HubAccount) {
 		fatalError("Abstract method receivedExistingKey(jwe:privateKey:hubAccount:) not implemented")
 	}

 	func setState(to newState: AddHubVaultViewModelState) {
 		DispatchQueue.main.async {
 			self.state = newState
 		}
 	}

 	func setError(to newError: Error?) {
 		DispatchQueue.main.async {
 			self.error = newError
 		}
 	}
 }
 */
