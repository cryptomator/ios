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

protocol LocalFileSystemAuthenticationViewModelProtocol: SingleSectionTableViewModel {
	var headerText: String { get }
	var documentPickerStartDirectoryURL: URL? { get }
	func footerViewModel(for section: Int) -> HeaderFooterViewModel?
	func userPicked(urls: [URL]) throws -> LocalFileSystemCredential
}

protocol LocalFileSystemVaultInstallingViewModelProtocol {
	func addVault(for credential: LocalFileSystemCredential) -> Promise<LocalFileSystemAuthenticationResult>
}

protocol LocalFileSystemAuthenticationValidationLogic {
	func validate(items: [CloudItemMetadata]) throws
}

class LocalFileSystemAuthenticationViewModel: SingleSectionTableViewModel, LocalFileSystemAuthenticationViewModelProtocol {
	override var cells: [TableViewCellViewModel] {
		return [openDocumentPickerCellViewModel]
	}

	var documentPickerStartDirectoryURL: URL? {
		switch selectedLocalFileSystemType {
		case .iCloudDrive:
			return LocalFileSystemAuthenticationViewModel.iCloudDriveRootDirectory
		case .custom:
			return nil
		}
	}

	public static let iCloudDriveRootDirectory = URL(fileURLWithPath: "\(iCloudDrivePrefix)com~apple~CloudDocs/")
	private static let iCloudDrivePrefix = "/private/var/mobile/Library/Mobile Documents/"
	let documentPickerButtonText: String
	let headerText: String
	lazy var openDocumentPickerCellViewModel = ButtonCellViewModel(action: "openDocumentPicker", title: documentPickerButtonText)

	private let validationLogic: LocalFileSystemAuthenticationValidationLogic
	private let accountManager: CloudProviderAccountManager
	private let selectedLocalFileSystemType: LocalFileSystemType

	init(documentPickerButtonText: String, headerText: String, selectedLocalFileSystemType: LocalFileSystemType, validationLogic: LocalFileSystemAuthenticationValidationLogic, accountManager: CloudProviderAccountManager) {
		self.documentPickerButtonText = documentPickerButtonText
		self.headerText = headerText
		self.selectedLocalFileSystemType = selectedLocalFileSystemType
		self.validationLogic = validationLogic
		self.accountManager = accountManager
	}

	func footerViewModel(for section: Int) -> HeaderFooterViewModel? {
		switch selectedLocalFileSystemType {
		case .iCloudDrive:
			return nil
		case .custom:
			return LocalFileSystemAuthenticationInfoFooterViewModel()
		}
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
		let provider: CloudProvider
		do {
			provider = try LocalizedCloudProviderDecorator(delegate: LocalFileSystemProvider(rootURL: credential.rootURL))
		} catch {
			return Promise(error)
		}
		return provider.fetchItemListExhaustively(forFolderAt: CloudPath("/")).then { itemList in
			try self.validationLogic.validate(items: itemList.items)
		}
	}

	private func save(credential: LocalFileSystemCredential) throws -> CloudProviderAccount {
		try LocalFileSystemBookmarkManager.saveBookmarkForRootURL(credential.rootURL, for: credential.identifier)
		let account = CloudProviderAccount(accountUID: credential.identifier, cloudProviderType: .localFileSystem(type: getLocalFileSystemType(for: credential.rootURL)))
		try accountManager.saveNewAccount(account)
		return account
	}

	/**

	 */
	private func getLocalFileSystemType(for url: URL) -> LocalFileSystemType {
		if url.path.hasPrefix(LocalFileSystemAuthenticationViewModel.iCloudDrivePrefix) {
			return .iCloudDrive
		} else {
			return .custom
		}
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

class LocalFileSystemAuthenticationInfoFooterViewModel: AttributedTextHeaderFooterViewModel {
	init() {
		let infoText = LocalizedString.getValue("localFileSystemAuthentication.info.footer")
		let text = NSMutableAttributedString(string: infoText)
		text.append(NSAttributedString(string: " "))
		let learnMoreLink = NSAttributedString(string: LocalizedString.getValue("common.footer.learnMore"), attributes: [NSAttributedString.Key.link: URL(string: "https://docs.cryptomator.org/en/1.6/ios/cloud-management/#other-file-provider")!])
		text.append(learnMoreLink)
		super.init(attributedText: text)
	}
}
