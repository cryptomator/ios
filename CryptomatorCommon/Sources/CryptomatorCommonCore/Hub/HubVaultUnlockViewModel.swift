//
//  HubVaultUnlockViewModel.swift
//
//
//  Created by Philipp Schmid on 22.07.22.
//

import CryptoKit
import CryptomatorCloudAccessCore
import CryptomatorCryptoLib
import FileProvider
import Foundation
import JOSESwift
import Promises

class HubVaultUnlockViewModel: HubVaultViewModel {
	let fileProviderConnector: FileProviderConnector
	let domain: NSFileProviderDomain
	private weak var unlockDelegate: HubVaultUnlockDelegate?

	init(hubAccount: HubAccount, domain: NSFileProviderDomain, fileProviderConnector: FileProviderConnector, vaultConfig: UnverifiedVaultConfig, coordinator: (HubVaultCoordinator & HubVaultUnlockDelegate)? = nil) {
		self.fileProviderConnector = fileProviderConnector
		self.domain = domain
		self.unlockDelegate = coordinator
		super.init(initialState: .loading(text: "Cryptomator is receiving and processing the response from Hub. Please wait."), vaultConfig: vaultConfig, coordinator: coordinator)
		self.authState = hubAccount.authState
		Task {
			await continueToAccessCheck()
		}
	}

	override func receivedExistingKey(jwe: JWE, privateKey: P384.KeyAgreement.PrivateKey, hubAccount: HubAccount) async {
		let masterkey: Masterkey
		do {
			masterkey = try JWEHelper.decrypt(jwe: jwe, with: privateKey)
		} catch {
			await setError(to: error)
			return
		}
		let xpc: XPC<VaultUnlocking>
		do {
			xpc = try await fileProviderConnector.getXPC(serviceName: .vaultUnlocking, domain: domain)
			defer {
				fileProviderConnector.invalidateXPC(xpc)
			}
			try await xpc.proxy.unlockVault(rawKey: masterkey.rawKey).getValue()
			unlockDelegate?.unlockedVault()
			fileProviderConnector.invalidateXPC(xpc)
		} catch {
			await setError(to: error)
		}
	}
}

extension Promise {
	func getValue() async throws -> Value {
		try await withCheckedThrowingContinuation({ continuation in
			self.then(continuation.resume(returning:)).catch(continuation.resume(throwing:))
		})
	}
}
