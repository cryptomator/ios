//
//  CreateNewLocalVaultViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 24.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import Foundation
import Promises

class CreateNewLocalVaultViewModel: LocalFileSystemAuthenticationViewModel, LocalFileSystemVaultInstallingViewModelProtocol {
	private let vaultName: String

	init(vaultName: String, selectedLocalFileSystemType: LocalFileSystemType, accountManager: CloudProviderAccountManager = CloudProviderAccountDBManager.shared) {
		let documentPickerButtonText = LocalizedString.getValue("localFileSystemAuthentication.createNewVault.button")
		let headerText: String
		switch selectedLocalFileSystemType {
		case .iCloudDrive:
			headerText = LocalizedString.getValue("localFileSystemAuthentication.createNewVault.iCloudDrive.header")
		case .custom:
			headerText = LocalizedString.getValue("localFileSystemAuthentication.createNewVault.otherFileProvider.header")
		}
		self.vaultName = vaultName
		super.init(documentPickerButtonText: documentPickerButtonText, headerText: headerText, selectedLocalFileSystemType: selectedLocalFileSystemType, validationLogic: CreateNewLocalVaultValidationLogic(vaultName: vaultName), accountManager: accountManager)
	}

	func addVault(for credential: LocalFileSystemCredential) -> Promise<LocalFileSystemAuthenticationResult> {
		return validateAndSave(credential: credential).then { account -> LocalFileSystemAuthenticationResult in
			let vault = Folder(path: CloudPath("/\(self.vaultName)"))
			return LocalFileSystemAuthenticationResult(credential: credential, account: account, item: vault)
		}
	}
}

private class CreateNewLocalVaultValidationLogic: LocalFileSystemAuthenticationValidationLogic {
	private let vaultName: String
	init(vaultName: String) {
		self.vaultName = vaultName
	}

	func validate(items: [CloudItemMetadata]) throws {
		guard VaultDetector.getVaultItem(items: items, parentCloudPath: CloudPath("/")) == nil else {
			throw CreateNewLocalVaultViewModelError.detectedExistingVault
		}
		guard !items.contains(where: { $0.name == vaultName }) else {
			throw CreateNewVaultChooseFolderViewModelError.vaultNameCollision(name: vaultName)
		}
	}
}

enum CreateNewLocalVaultViewModelError: LocalizedError {
	case detectedExistingVault

	var errorDescription: String? {
		switch self {
		case .detectedExistingVault:
			return LocalizedString.getValue("localFileSystemAuthentication.createNewVault.error.detectedExistingVault")
		}
	}
}
