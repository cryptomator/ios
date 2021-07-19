//
//  LocalFileSystemAuthenticationViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 21.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import Foundation
import Promises

protocol LocalFileSystemAuthenticationViewModelProtocol {
	var documentPickerButtonText: String { get }
	var headerText: String { get }
	func userPicked(urls: [URL]) throws -> LocalFileSystemCredential
}

protocol LocalFileSystemVaultInstallingViewModelProtocol {
	func addVault(for credential: LocalFileSystemCredential) -> Promise<LocalFileSystemAuthenticationResult>
}

protocol LocalFileSystemAuthenticationValidationLogic {
	func validate(items: [CloudItemMetadata]) throws
}

class LocalFileSystemAuthenticationViewModel: LocalFileSystemAuthenticationViewModelProtocol {
	let documentPickerButtonText: String
	let headerText: String
	private let validationLogic: LocalFileSystemAuthenticationValidationLogic
	private let accountManager: CloudProviderAccountManager

	init(documentPickerButtonText: String, headerText: String, validationLogic: LocalFileSystemAuthenticationValidationLogic, accountManager: CloudProviderAccountManager) {
		self.documentPickerButtonText = documentPickerButtonText
		self.headerText = headerText
		self.validationLogic = validationLogic
		self.accountManager = accountManager
	}

	func userPicked(urls: [URL]) throws -> LocalFileSystemCredential {
		guard let rootURL = urls.first else {
			throw LocalFileSystemAuthenticationViewModelError.invalidURL
		}
		let credential = LocalFileSystemCredential(rootURL: rootURL, identifier: UUID().uuidString)
		return credential
	}

	func validateAndSave(credential: LocalFileSystemCredential) -> Promise<CloudProviderAccount> {
		return validate(credential: credential).then {
			try self.save(credential: credential)
		}
	}

	private func validate(credential: LocalFileSystemCredential) -> Promise<Void> {
		let provider = LocalFileSystemProvider(rootURL: credential.rootURL)
		return provider.fetchItemListExhaustively(forFolderAt: CloudPath("/")).recover { error -> CloudItemList in
			if let error = error as? CloudProviderError {
				throw LocalizedCloudProviderError.convertToLocalized(error, cloudPath: CloudPath("/"))
			} else {
				throw error
			}
		}.then { itemList in
			try self.validationLogic.validate(items: itemList.items)
		}
	}

	private func save(credential: LocalFileSystemCredential) throws -> CloudProviderAccount {
		try LocalFileSystemBookmarkManager.saveBookmarkForRootURL(credential.rootURL, for: credential.identifier)
		let account = CloudProviderAccount(accountUID: credential.identifier, cloudProviderType: .localFileSystem)
		try accountManager.saveNewAccount(account)
		return account
	}
}

struct LocalFileSystemCredential {
	let rootURL: URL
	let identifier: String
}

struct LocalFileSystemAuthenticationResult {
	let credential: LocalFileSystemCredential
	let account: CloudProviderAccount
	let item: Item
}

enum LocalFileSystemAuthenticationViewModelError: Error {
	case invalidURL
}
