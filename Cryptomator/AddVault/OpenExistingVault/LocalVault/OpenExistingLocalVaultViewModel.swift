//
//  OpenExistingLocalVaultViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 23.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import Foundation
import Promises

class OpenExistingLocalVaultViewModel: LocalFileSystemAuthenticationViewModel, LocalFileSystemVaultInstallingViewModelProtocol {
	private let validator: OpenExistingLocalVaultValidationLogic
	init(selectedLocalFileSystemType: LocalFileSystemType, accountManager: CloudProviderAccountManager = CloudProviderAccountDBManager.shared) {
		let documentPickerButtonText = LocalizedString.getValue("localFileSystemAuthentication.openExistingVault.button")
		let headerText = LocalizedString.getValue("localFileSystemAuthentication.openExistingVault.header")
		self.validator = OpenExistingLocalVaultValidationLogic()
		super.init(documentPickerButtonText: documentPickerButtonText, headerText: headerText, selectedLocalFileSystemType: selectedLocalFileSystemType, validationLogic: validator, accountManager: accountManager)
	}

	func addVault(for credential: LocalFileSystemCredential) -> Promise<LocalFileSystemAuthenticationResult> {
		return validateAndSave(credential: credential).then { account -> LocalFileSystemAuthenticationResult in
			guard let detectedVaultItem = self.validator.vaultItem else {
				throw OpenExistingLocalVaultViewModelError.noVaultFound
			}
			let vaultItem = VaultDetailItem(name: credential.rootURL.lastPathComponent, vaultPath: detectedVaultItem.vaultPath, isLegacyVault: detectedVaultItem.isLegacyVault)
			return LocalFileSystemAuthenticationResult(credential: credential, account: account, item: vaultItem)
		}
	}
}

private class OpenExistingLocalVaultValidationLogic: LocalFileSystemAuthenticationValidationLogic {
	var vaultItem: VaultDetailItem?
	func validate(items: [CloudItemMetadata]) throws {
		guard let vaultItem = VaultDetector.getVaultItem(items: items, parentCloudPath: CloudPath("/")) else {
			throw OpenExistingLocalVaultViewModelError.noVaultFound
		}
		self.vaultItem = vaultItem
	}
}

enum OpenExistingLocalVaultViewModelError: LocalizedError {
	case noVaultFound

	var errorDescription: String? {
		switch self {
		case .noVaultFound:
			return LocalizedString.getValue("localFileSystemAuthentication.openExistingVault.error.noVaultFound")
		}
	}
}
