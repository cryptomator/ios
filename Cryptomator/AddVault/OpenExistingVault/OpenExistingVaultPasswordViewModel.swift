//
//  OpenExistingVaultPasswordViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 29.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CloudAccessPrivateCore
import CryptomatorCloudAccess
import Foundation
import Promises
protocol OpenExistingVaultPasswordViewModelProtocol {
	var password: String? { get set }
	var footerTitle: String { get }
	var vaultName: String { get }
	// This function is later no longer asynchronous
	func addVault() -> Promise<Void>
}

class OpenExistingVaultPasswordViewModel: OpenExistingVaultPasswordViewModelProtocol {
	var password: String?
	let provider: CloudProvider
	let account: CloudProviderAccount

	// later: localMasterkeyURL: URL instead of masterkeyPath: CloudPath
	let masterkeyPath: CloudPath
	var vaultName: String {
		let masterkeyParentPath = masterkeyPath.deletingLastPathComponent()
		return masterkeyParentPath.lastPathComponent
	}

	var footerTitle: String {
		return "Enter password for \"\(vaultName)\""
	}

	private let localMasterkeyURL: URL
	private let vaultID: String

	init(provider: CloudProvider, account: CloudProviderAccount, masterkeyPath: CloudPath, vaultID: String) {
		self.provider = provider
		self.account = account
		self.masterkeyPath = masterkeyPath
		let tmpDirURL = FileManager.default.temporaryDirectory
		self.localMasterkeyURL = tmpDirURL.appendingPathComponent(UUID().uuidString, isDirectory: false)
		self.vaultID = vaultID
	}

	func addVault() -> Promise<Void> {
		#warning("TODO: Remove Async Implementation")
		guard let password = password else {
			return Promise(MasterkeyProcessingViewModelError.noPasswordSet)
		}
		return VaultManager.shared.createFromExisting(withVaultID: vaultID, delegateAccountUID: account.accountUID, masterkeyPath: masterkeyPath, password: password, storePasswordInKeychain: true).then {
			
		}
	}
}

enum MasterkeyProcessingViewModelError: Error {
	case noPasswordSet
}
