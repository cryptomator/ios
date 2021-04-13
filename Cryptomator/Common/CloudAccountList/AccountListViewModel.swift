//
//  AccountListViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 19.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import Foundation
import GRDB
import Promises
class AccountListViewModel: AccountListViewModelProtocol {
	let cloudProviderType: CloudProviderType
	private let dbManager: DatabaseManager
	private let cloudAuthenticator: CloudAuthenticator
	private var observation: TransactionObserver?

	init(with cloudProviderType: CloudProviderType,
	     dbManager: DatabaseManager = DatabaseManager.shared,
	     cloudAuthenticator: CloudAuthenticator = CloudAuthenticator(accountManager: CloudProviderAccountManager.shared))
	{
		self.cloudProviderType = cloudProviderType
		self.dbManager = dbManager
		self.cloudAuthenticator = cloudAuthenticator
	}

	private(set) var accounts = [AccountCellContent]()
	private(set) var accountInfos = [AccountInfo]()
	var title: String {
		cloudProviderType.localizedString()
	}

	func refreshItems() throws {
		let refreshedAccountInfos = try dbManager.getAllAccounts(for: cloudProviderType)
		let refreshedAccounts = try refreshedAccountInfos.map { try createAccountCellContent(from: $0) }
		accountInfos = refreshedAccountInfos
		accounts = refreshedAccounts
	}

	func refreshDropboxItems() -> Promise<Void> {
		return all(accountInfos
			.map { DropboxCredential(tokenUid: $0.accountUID) }
			.map { self.createAccountCellContent(for: $0) }
		).then { accounts in
			self.accounts = accounts
		}
	}

	func createAccountCellContent(from accountInfo: AccountInfo) throws -> AccountCellContent {
		switch cloudProviderType {
		case .dropbox:
			let credential = DropboxCredential(tokenUid: accountInfo.accountUID)
			return createAccountCellContentPlaceholder(for: credential)
		case .googleDrive:
			let credential = GoogleDriveCredential(with: accountInfo.accountUID)
			return try createAccountCellContent(for: credential)
		case .webDAV:
			guard let credential = WebDAVAuthenticator.getCredentialFromKeychain(with: accountInfo.accountUID) else {
				throw CloudProviderAccountError.accountNotFoundError
			}
			return createAccountCellContent(for: credential)
		case .localFileSystem:
			throw AccountListError.unsupportedCloudProviderType
		}
	}

	private func createAccountCellContent(for credential: DropboxCredential) -> Promise<AccountCellContent> {
		return credential.getUsername().then { username in
			AccountCellContent(mainLabelText: username, detailLabelText: nil)
		}
	}

	private func createAccountCellContentPlaceholder(for credential: DropboxCredential) -> AccountCellContent {
		let placeholder = "Loading..."
		return AccountCellContent(mainLabelText: placeholder, detailLabelText: nil)
	}

	private func createAccountCellContent(for credential: GoogleDriveCredential) throws -> AccountCellContent {
		let username = try credential.getUsername()
		return AccountCellContent(mainLabelText: username, detailLabelText: nil)
	}

	func createAccountCellContent(for credential: WebDAVCredential) -> AccountCellContent {
		let detailLabelText: String
		let path = credential.baseURL.path
		if path.count > 0, path != "/" {
			detailLabelText = "\(credential.username) • \(path)"
		} else {
			detailLabelText = credential.username
		}
		return AccountCellContent(mainLabelText: credential.baseURL.host ?? "<unknown-host>", detailLabelText: detailLabelText)
	}

	func moveRow(at sourceIndex: Int, to destinationIndex: Int) throws {
		let movedAccountCell = accounts.remove(at: sourceIndex)
		let movedAccountInfo = accountInfos.remove(at: sourceIndex)
		accounts.insert(movedAccountCell, at: destinationIndex)
		accountInfos.insert(movedAccountInfo, at: destinationIndex)
		try updateAccountListPositions()
	}

	func removeRow(at index: Int) throws {
		_ = accounts.remove(at: index)
		let removedAccountInfo = accountInfos.remove(at: index)
		try cloudAuthenticator.deauthenticate(account: removedAccountInfo.cloudProviderAccount)
		try updateAccountListPositions()
	}

	func startListenForChanges(onError: @escaping (Error) -> Void, onChange: @escaping () -> Void) {
		observation = dbManager.observeCloudProviderAccounts(onError: onError, onChange: { _ in
			do {
				try self.refreshItems()
				onChange()
			} catch {
				onError(error)
				return
			}
			if self.cloudProviderType == .dropbox {
				self.refreshDropboxItems().then {
					onChange()
				}.catch { error in
					onError(error)
				}
			}
		})
	}

	private func updateAccountListPositions() throws {
		for i in accountInfos.indices {
			accountInfos[i].listPosition = i
		}
		let updatedAccountListPositions = accountInfos.map { $0.accountListPosition }
		try dbManager.updateAccountListPositions(updatedAccountListPositions)
	}
}

enum AccountListError: Error {
	case unsupportedCloudProviderType
}
