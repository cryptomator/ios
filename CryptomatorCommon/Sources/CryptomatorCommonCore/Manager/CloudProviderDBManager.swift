//
//  CloudProviderDBManager.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 20.10.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation
import PCloudSDKSwift

public protocol CloudProviderManager {
	func getProvider(with accountUID: String) throws -> CloudProvider
}

public protocol CloudProviderUpdating {
	func providerShouldUpdate(with accountUID: String)
}

public class CloudProviderDBManager: CloudProviderManager, CloudProviderUpdating {
	static var cachedProvider = [String: CloudProvider]()
	public static let shared = CloudProviderDBManager(accountManager: CloudProviderAccountDBManager.shared)
	public var useBackgroundSession = true
	let accountManager: CloudProviderAccountDBManager

	private let maxPageSizeForFileProvider = 500

	init(accountManager: CloudProviderAccountDBManager) {
		self.accountManager = accountManager
	}

	public func getProvider(with accountUID: String) throws -> CloudProvider {
		if let provider = CloudProviderDBManager.cachedProvider[accountUID] {
			return provider
		}
		return try createProvider(for: accountUID)
	}

	/**
	 Creates and returns a cloud provider for the given `accountUID`.

	 If `useBackgroundURLSession` is set to `true`, the number of returned items from a `fetchItemList(forFolderAt:pageToken:)` call is limited to 500.
	 This is necessary because otherwise memory limit problems can occur with folders with many items in the `FileProviderExtension` where a background `URLSession` is used.
	 */
	func createProvider(for accountUID: String) throws -> CloudProvider {
		let cloudProviderType = try accountManager.getCloudProviderType(for: accountUID)
		let provider: CloudProvider
		switch cloudProviderType {
		case .dropbox:
			let credential = DropboxCredential(tokenUID: accountUID)
			provider = DropboxCloudProvider(credential: credential, maxPageSize: useBackgroundSession ? maxPageSizeForFileProvider : .max)
		case .googleDrive:
			let credential = GoogleDriveCredential(userID: accountUID)
			provider = try GoogleDriveCloudProvider(credential: credential,
			                                        useBackgroundSession: useBackgroundSession,
			                                        maxPageSize: useBackgroundSession ? maxPageSizeForFileProvider : .max)
		case .oneDrive:
			let credential = try OneDriveCredential(with: accountUID)
			provider = try OneDriveCloudProvider(credential: credential,
			                                     useBackgroundSession: useBackgroundSession,
			                                     maxPageSize: useBackgroundSession ? maxPageSizeForFileProvider : .max)
		case .pCloud:
			provider = try createPCloudProvider(for: accountUID)
		case .webDAV:
			guard let credential = WebDAVCredentialManager.shared.getCredentialFromKeychain(with: accountUID) else {
				throw CloudProviderAccountError.accountNotFoundError
			}
			let client: WebDAVClient
			if useBackgroundSession {
				client = WebDAVClient.withBackgroundSession(credential: credential, sharedContainerIdentifier: CryptomatorConstants.appGroupName)
			} else {
				client = WebDAVClient(credential: credential)
			}
			provider = try WebDAVProvider(with: client, maxPageSize: useBackgroundSession ? maxPageSizeForFileProvider : .max)
		case .localFileSystem:
			guard let rootURL = try LocalFileSystemBookmarkManager.getBookmarkedRootURL(for: accountUID) else {
				throw CloudProviderAccountError.accountNotFoundError
			}
			provider = try LocalFileSystemProvider(rootURL: rootURL, maxPageSize: useBackgroundSession ? maxPageSizeForFileProvider : .max)
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

	private func createPCloudProvider(for accountUID: String) throws -> CloudProvider {
		let credential = try PCloudCredential(userID: accountUID)
		let client: PCloudClient
		if useBackgroundSession {
			client = PCloud.createBackgroundClient(with: credential.user, sharedContainerIdentifier: CryptomatorConstants.appGroupName)
		} else {
			client = PCloud.createClient(with: credential.user)
		}
		return try PCloudCloudProvider(client: client)
	}

	public func providerShouldUpdate(with accountUID: String) {
		CloudProviderDBManager.cachedProvider[accountUID] = nil
		// call XPCService for FileProvider
	}
}
