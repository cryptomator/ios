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
		var refreshedAccounts: [AccountCellContent] = []
		var validAccountInfos: [AccountInfo] = []

		for accountInfo in refreshedAccountInfos {
			do {
				let accountContent = try createAccountCellContent(from: accountInfo)
				refreshedAccounts.append(accountContent)
				validAccountInfos.append(accountInfo)
			} catch CloudProviderAccountError.accountNotFoundError {
				DDLogError("Account \(accountInfo.accountUID) not found in keychain, skipping")
			} catch {
				DDLogError("Error creating account cell content for \(accountInfo.accountUID): \(error)")
				throw error
			}
		}

		accountInfos = validAccountInfos
		accounts = refreshedAccounts
	}

	func refreshDropboxItems() async throws {
		accounts = try await all(accountInfos
			.map { DropboxCredential(tokenUID: $0.accountUID) }
			.map { credential in Task { try await self.createAccountCellContent(for: credential) } })
	}

	func refreshMicrosoftGraphItems() async throws {
		accounts = try await all(accountInfos
			.compactMap { try? MicrosoftGraphAccountDBManager.shared.getAccount(for: $0.accountUID) }
			.compactMap { try? self.createAccountCellContent(for: $0) })
	}

	func refreshPCloudItems() async throws {
		accounts = try await all(accountInfos
			.compactMap { try? PCloudCredential(userID: $0.accountUID) }
			.map { credential in Task { try await self.createAccountCellContent(for: credential) } })
	}

	func refreshBoxItems() async throws {
		accounts = try await all(accountInfos
			.map { BoxCredential(tokenStorage: BoxTokenStorage(userID: $0.accountUID)) }
			.map { credential in Task { try await self.createAccountCellContent(for: credential) } })
	}

	private func all(_ tasks: [Task<AccountCellContent, Error>]) async throws -> [AccountCellContent] {
		var accounts = [AccountCellContent]()
		for task in tasks {
			try await accounts.append(task.value)
		}
		return accounts
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
		case .microsoftGraph:
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

	private func createAccountCellContent(for credential: DropboxCredential) async throws -> AccountCellContent {
		let username = try await credential.getUsername()
		return AccountCellContent(mainLabelText: username, detailLabelText: nil)
	}

	private func createAccountCellContent(for credential: GoogleDriveCredential) throws -> AccountCellContent {
		let username = try credential.getUsername()
		return AccountCellContent(mainLabelText: username, detailLabelText: nil)
	}

	func createAccountCellContentPlaceholder(for account: MicrosoftGraphAccount) throws -> AccountCellContent {
		let credential = MicrosoftGraphCredential(identifier: account.credentialID, type: account.type)
		let username = try credential.getUsername()
		var detailLabelTextComponents: [String] = []
		if let siteURL = account.siteURL?.absoluteString.replacingOccurrences(of: "https://", with: "") {
			detailLabelTextComponents.append(siteURL)
		}
		if account.driveID != nil {
			detailLabelTextComponents.append("(…)")
		}
		let detailLabelText = detailLabelTextComponents.joined(separator: " • ")
		return AccountCellContent(mainLabelText: username, detailLabelText: detailLabelText)
	}

	func createAccountCellContent(for account: MicrosoftGraphAccount) throws -> Task<AccountCellContent, Error> {
		guard let driveID = account.driveID else {
			let accountCellContent = try createAccountCellContentPlaceholder(for: account)
			return Task { accountCellContent }
		}
		let credential = MicrosoftGraphCredential(identifier: account.credentialID, type: account.type)
		let username = try credential.getUsername()
		let discovery = MicrosoftGraphDiscovery(credential: credential)
		return Task {
			let drive = try await discovery.fetchDrive(for: driveID)
			var detailLabelTextComponents: [String] = []
			if let siteURL = account.siteURL?.absoluteString.replacingOccurrences(of: "https://", with: "") {
				detailLabelTextComponents.append(siteURL)
			}
			detailLabelTextComponents.append("\(drive.name ?? "<unknown-drive-name>")")
			let detailLabelText = detailLabelTextComponents.joined(separator: " • ")
			return AccountCellContent(mainLabelText: username, detailLabelText: detailLabelText)
		}
	}

	func createAccountCellContent(for credential: PCloudCredential) async throws -> AccountCellContent {
		let username = try await credential.getUsername()
		return AccountCellContent(mainLabelText: username, detailLabelText: nil)
	}

	func createAccountCellContent(for credential: BoxCredential) async throws -> AccountCellContent {
		let username = try await credential.getUsername()
		return AccountCellContent(mainLabelText: username, detailLabelText: nil)
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
		} catch {
			removedRow = false
			throw error
		}
	}

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
			let refreshOnlineItems: () async throws -> Void
			switch self.cloudProviderType {
			case .box:
				refreshOnlineItems = self.refreshBoxItems
			case .dropbox:
				refreshOnlineItems = self.refreshDropboxItems
			case .microsoftGraph:
				refreshOnlineItems = self.refreshMicrosoftGraphItems
			case .pCloud:
				refreshOnlineItems = self.refreshPCloudItems
			default:
				return
			}
			Task {
				do {
					try await refreshOnlineItems()
					self.databaseChangedPublisher.send(.success(self.accounts))
				} catch {
					self.databaseChangedPublisher.send(.failure(error))
				}
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
