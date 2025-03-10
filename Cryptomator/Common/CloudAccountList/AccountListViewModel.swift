//
//  AccountListViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 19.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import Combine
import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import Foundation
import GRDB
import Promises

class AccountListViewModel: AccountListViewModelProtocol {
	let headerTitle = LocalizedString.getValue("accountList.header.title")
	let emptyListMessage = LocalizedString.getValue("accountList.emptyList.message")
	let removeAlert = ListViewModelAlertContent(title: LocalizedString.getValue("accountList.signOut.alert.title"),
	                                            message: LocalizedString.getValue("accountList.signOut.alert.message"),
	                                            confirmButtonText: LocalizedString.getValue("common.button.signOut"))
	let cloudProviderType: CloudProviderType
	private let dbManager: DatabaseManager
	private let cloudAuthenticator: CloudAuthenticator
	private var observation: DatabaseCancellable?
	private lazy var databaseChangedPublisher = CurrentValueSubject<Result<[TableViewCellViewModel], Error>, Never>(.success([]))
	private var removedRow = false
	private var cancellable: AnyCancellable?

	init(with cloudProviderType: CloudProviderType, dbManager: DatabaseManager = DatabaseManager.shared, cloudAuthenticator: CloudAuthenticator = CloudAuthenticator(accountManager: CloudProviderAccountDBManager.shared)) {
		self.cloudProviderType = cloudProviderType
		self.dbManager = dbManager
		self.cloudAuthenticator = cloudAuthenticator
		setupBinding()
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
			.map { DropboxCredential(tokenUID: $0.accountUID) }
			.map { self.createAccountCellContent(for: $0) }
		).then { accounts in
			self.accounts = accounts
		}
	}

	func refreshMicrosoftGraphItems() -> Promise<Void> {
		return all(accountInfos
			.compactMap { try? MicrosoftGraphAccountDBManager.shared.getAccount(for: $0.accountUID) }
			.compactMap { try? self.createAccountCellContent(for: $0) }
		).then { accounts in
			self.accounts = accounts
		}
	}

	func refreshPCloudItems() -> Promise<Void> {
		return all(accountInfos
			.compactMap { try? PCloudCredential(userID: $0.accountUID) }
			.map { self.createAccountCellContent(for: $0) }
		).then { accounts in
			self.accounts = accounts
		}
	}

	func refreshBoxItems() -> Promise<Void> {
		return all(accountInfos
			.map { BoxCredential(tokenStorage: BoxTokenStorage(userID: $0.accountUID)) }
			.map { self.createAccountCellContent(for: $0) }
		).then { accounts in
			self.accounts = accounts
		}
	}

	func createAccountCellContent(from accountInfo: AccountInfo) throws -> AccountCellContent {
		switch cloudProviderType {
		case .box:
			return createAccountCellContentPlaceholder()
		case .dropbox:
			return createAccountCellContentPlaceholder()
		case .googleDrive:
			let credential = GoogleDriveCredential(userID: accountInfo.accountUID)
			return try createAccountCellContent(for: credential)
		case .localFileSystem:
			throw AccountListError.unsupportedCloudProviderType
		case let .microsoftGraph(type):
			let account = try MicrosoftGraphAccountDBManager.shared.getAccount(for: accountInfo.accountUID)
			return try createAccountCellContentPlaceholder(for: account)
		case .pCloud:
			return createAccountCellContentPlaceholder()
		case .s3:
			guard let credential = S3CredentialManager.shared.getCredential(with: accountInfo.accountUID) else {
				throw CloudProviderAccountError.accountNotFoundError
			}
			let displayName = try S3CredentialManager.shared.getDisplayName(for: credential)
			return createAccountCellContent(for: credential, displayName: displayName)
		case .webDAV:
			guard let credential = WebDAVCredentialManager.shared.getCredentialFromKeychain(with: accountInfo.accountUID) else {
				throw CloudProviderAccountError.accountNotFoundError
			}
			return createAccountCellContent(for: credential)
		}
	}

	private func createAccountCellContentPlaceholder() -> AccountCellContent {
		return AccountCellContent(mainLabelText: "(…)", detailLabelText: nil)
	}

	private func createAccountCellContent(for credential: DropboxCredential) -> Promise<AccountCellContent> {
		return credential.getUsername().then { username in
			AccountCellContent(mainLabelText: username, detailLabelText: nil)
		}
	}

	private func createAccountCellContent(for credential: GoogleDriveCredential) throws -> AccountCellContent {
		let username = try credential.getUsername()
		return AccountCellContent(mainLabelText: username, detailLabelText: nil)
	}

	func createAccountCellContentPlaceholder(for account: MicrosoftGraphAccount) throws -> AccountCellContent {
		let credential = MicrosoftGraphCredential(identifier: account.accountUID, type: account.type)
		let username = try credential.getUsername()
		let detailLabelText = account.driveID != nil ? "(…)" : nil
		return AccountCellContent(mainLabelText: username, detailLabelText: detailLabelText)
	}

	func createAccountCellContent(for account: MicrosoftGraphAccount) throws -> Promise<AccountCellContent> {
		guard let driveID = account.driveID else {
			return try Promise(createAccountCellContentPlaceholder(for: account))
		}
		let credential = MicrosoftGraphCredential(identifier: account.accountUID, type: account.type)
		let username = try credential.getUsername()
		let discovery = MicrosoftGraphDiscovery(credential: credential)
		return discovery.fetchDrive(for: driveID).then { drive in
			let detailLabelText = "\(drive.name ?? "<unknown-drive-name>")"
			return AccountCellContent(mainLabelText: username, detailLabelText: detailLabelText)
		}
	}

	func createAccountCellContent(for credential: PCloudCredential) -> Promise<AccountCellContent> {
		return credential.getUsername().then { username in
			AccountCellContent(mainLabelText: username, detailLabelText: nil)
		}
	}

	func createAccountCellContent(for credential: BoxCredential) -> Promise<AccountCellContent> {
		return credential.getUsername().then { username in
			AccountCellContent(mainLabelText: username, detailLabelText: nil)
		}
	}

	func createAccountCellContent(for credential: WebDAVCredential) -> AccountCellContent {
		let detailLabelText: String
		let path = credential.baseURL.path
		if !path.isEmpty, path != "/" {
			detailLabelText = "\(credential.username) • \(path)"
		} else {
			detailLabelText = credential.username
		}
		return AccountCellContent(mainLabelText: credential.baseURL.host ?? "<unknown-host>", detailLabelText: detailLabelText)
	}

	func createAccountCellContent(for credential: S3Credential, displayName: String?) -> AccountCellContent {
		let hostName = credential.url.host ?? "<unknown-host>"
		let detailLabelText = "\(hostName) • \(credential.bucket)"
		return AccountCellContent(mainLabelText: displayName ?? "<unknown-display-name>", detailLabelText: detailLabelText)
	}

	func moveRow(at sourceIndex: Int, to destinationIndex: Int) throws {
		let movedAccountCell = accounts.remove(at: sourceIndex)
		let movedAccountInfo = accountInfos.remove(at: sourceIndex)
		accounts.insert(movedAccountCell, at: destinationIndex)
		accountInfos.insert(movedAccountInfo, at: destinationIndex)
		try updateAccountListPositions()
		databaseChangedPublisher.send(.success(accounts))
	}

	func removeRow(at index: Int) throws {
		removedRow = true
		_ = accounts.remove(at: index)
		let removedAccountInfo = accountInfos.remove(at: index)
		do {
			try cloudAuthenticator.deauthenticate(account: removedAccountInfo.cloudProviderAccount)
			try updateAccountListPositions()
		} catch {
			removedRow = false
			throw error
		}
	}

	// swiftlint:disable:next function_body_length
	func startListenForChanges() -> AnyPublisher<Result<[TableViewCellViewModel], Error>, Never> {
		observation = dbManager.observeCloudProviderAccounts(onError: { error in
			DDLogError("Observe vault accounts failed with error: \(error)")
			self.databaseChangedPublisher.send(.failure(error))
		}, onChange: { _ in
			defer {
				self.removedRow = false
			}
			do {
				try self.refreshItems()
				if !self.removedRow {
					self.databaseChangedPublisher.send(.success(self.accounts))
				}
			} catch {
				DDLogError("RefreshItems failed with error: \(error)")
				self.databaseChangedPublisher.send(.failure(error))
				return
			}
			guard !self.removedRow else {
				return
			}
			guard !self.accounts.isEmpty else {
				// Only query the cloud provider online for the additional info if there are actually accounts to query.
				// Also fixes the problem that an empty account list is sent a second time via the `databaseChangedPublisher`.
				return
			}
			switch self.cloudProviderType {
			case .box:
				self.refreshBoxItems().then {
					self.databaseChangedPublisher.send(.success(self.accounts))
				}.catch { error in
					self.databaseChangedPublisher.send(.failure(error))
				}
			case .dropbox:
				self.refreshDropboxItems().then {
					self.databaseChangedPublisher.send(.success(self.accounts))
				}.catch { error in
					self.databaseChangedPublisher.send(.failure(error))
				}
			case .microsoftGraph:
				self.refreshMicrosoftGraphItems().then {
					self.databaseChangedPublisher.send(.success(self.accounts))
				}.catch { error in
					self.databaseChangedPublisher.send(.failure(error))
				}
			case .pCloud:
				self.refreshPCloudItems().then {
					self.databaseChangedPublisher.send(.success(self.accounts))
				}.catch { error in
					self.databaseChangedPublisher.send(.failure(error))
				}
			default:
				break
			}
		})
		return databaseChangedPublisher.eraseToAnyPublisher()
	}

	private func updateAccountListPositions() throws {
		for i in accountInfos.indices {
			accountInfos[i].listPosition = i
		}
		let updatedAccountListPositions = accountInfos.map { $0.accountListPosition }
		try dbManager.updateAccountListPositions(updatedAccountListPositions)
	}

	private func setupBinding() {
		if case CloudProviderType.webDAV = cloudProviderType {
			cancellable = WebDAVCredentialManager.shared.didUpdate.sink { [weak self] in
				self?.handleKeychainUpdate()
			}
		}
	}

	private func handleKeychainUpdate() {
		guard !removedRow else { return }
		do {
			try refreshItems()
			databaseChangedPublisher.send(.success(accounts))
		} catch {
			DDLogError("handleKeychainUpdate - refreshItems failed with error: \(error)")
			databaseChangedPublisher.send(.failure(error))
		}
	}
}

enum AccountListError: Error {
	case unsupportedCloudProviderType
}
