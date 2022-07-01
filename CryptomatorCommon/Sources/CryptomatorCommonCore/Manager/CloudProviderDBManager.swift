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
		case .dropbox:
			let credential = DropboxCredential(tokenUID: accountUID)
			provider = DropboxCloudProvider(credential: credential)
		case .googleDrive:
			let credential = GoogleDriveCredential(userID: accountUID)
			provider = try GoogleDriveCloudProvider(credential: credential, useBackgroundSession: useBackgroundSession)
		case .oneDrive:
			let credential = try OneDriveCredential(with: accountUID)
			provider = try OneDriveCloudProvider(credential: credential, useBackgroundSession: useBackgroundSession)
		case .pCloud:
			let credential = try PCloudCredential(userID: accountUID)
			provider = try PCloudCloudProvider(credential: credential)
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
		case .s3:
			provider = try createS3Provider(for: accountUID)
		}
		CloudProviderDBManager.cachedProvider[accountUID] = provider
		return provider
	}

	private func createS3Provider(for accountUID: String) throws -> CloudProvider {
		guard let credential = S3CredentialManager.shared.getCredential(with: accountUID) else {
			throw CloudProviderAccountError.accountNotFoundError
		}
		if useBackgroundSession {
			return try S3CloudProvider.withBackgroundSession(credential: credential, sharedContainerIdentifier: CryptomatorConstants.appGroupName)
		} else {
			return try S3CloudProvider(credential: credential)
		}
	}

	public static func providerShouldUpdate(with accountUID: String) {
		cachedProvider[accountUID] = nil
		// call XPCService for FileProvider
	}
}
