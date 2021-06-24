//
//  CloudProviderDBManager.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 20.10.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation
public protocol CloudProviderManager {
	func getProvider(with accountUID: String) throws -> CloudProvider
	static func providerShouldUpdate(with accountUID: String)
}

public class CloudProviderDBManager: CloudProviderManager {
	static var cachedProvider = [String: CloudProvider]()
	public static let shared = CloudProviderDBManager(accountManager: CloudProviderAccountDBManager.shared)
	public var useBackgroundSession = true
	let accountManager: CloudProviderAccountDBManager

	init(accountManager: CloudProviderAccountDBManager) {
		self.accountManager = accountManager
	}

	public func getProvider(with accountUID: String) throws -> CloudProvider {
		if let provider = CloudProviderDBManager.cachedProvider[accountUID] {
			return provider
		}
		return try createProvider(for: accountUID)
	}

	func createProvider(for accountUID: String) throws -> CloudProvider {
		let cloudProviderType = try accountManager.getCloudProviderType(for: accountUID)
		let provider: CloudProvider
		switch cloudProviderType {
		case .googleDrive:
			let credential = GoogleDriveCredential(tokenUID: accountUID)
			provider = GoogleDriveCloudProvider(credential: credential, useBackgroundSession: useBackgroundSession)
		case .dropbox:
			let credential = DropboxCredential(tokenUID: accountUID)
			provider = DropboxCloudProvider(credential: credential)
		case .oneDrive:
			let credential = try OneDriveCredential(with: accountUID)
			provider = try OneDriveCloudProvider(credential: credential, useBackgroundSession: useBackgroundSession)
		case .webDAV:
			guard let credential = WebDAVAuthenticator.getCredentialFromKeychain(with: accountUID) else {
				throw CloudProviderAccountError.accountNotFoundError
			}
			let client: WebDAVClient
			if useBackgroundSession {
				client = WebDAVClient.withBackgroundSession(credential: credential, sharedContainerIdentifier: CryptomatorConstants.appGroupName)
			} else {
				client = WebDAVClient(credential: credential)
			}
			provider = WebDAVProvider(with: client)
		case .localFileSystem:
			guard let rootURL = try LocalFileSystemBookmarkManager.getBookmarkedRootURL(for: accountUID) else {
				throw CloudProviderAccountError.accountNotFoundError
			}
			provider = LocalFileSystemProvider(rootURL: rootURL)
		}
		CloudProviderDBManager.cachedProvider[accountUID] = provider
		return provider
	}

	public static func providerShouldUpdate(with accountUID: String) {
		cachedProvider[accountUID] = nil
		// call XPCService for FileProvider
	}
}
