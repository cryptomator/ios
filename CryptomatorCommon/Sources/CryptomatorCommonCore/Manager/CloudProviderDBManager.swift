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
	func getBackgroundSessionProvider(with accountUID: String, sessionIdentifier: String) throws -> CloudProvider
}

public protocol CloudProviderUpdating {
	func providerShouldUpdate(with accountUID: String)
}

struct CachedProvider {
	let accountUID: String
	let provider: CloudProvider
	let backgroundSessionIdentifier: String?
	var isBackgroundSession: Bool { backgroundSessionIdentifier != nil }
}

public class CloudProviderDBManager: CloudProviderManager, CloudProviderUpdating {
	static var cachedProvider = [CachedProvider]()
	public static let shared = CloudProviderDBManager(accountManager: CloudProviderAccountDBManager.shared)
	let accountManager: CloudProviderAccountDBManager

	private let maxPageSizeForFileProvider = 500

	init(accountManager: CloudProviderAccountDBManager) {
		self.accountManager = accountManager
	}

	public func getProvider(with accountUID: String) throws -> CloudProvider {
		if let entry = CloudProviderDBManager.cachedProvider.first(where: {
			$0.accountUID == accountUID && !$0.isBackgroundSession
		}) {
			return entry.provider
		}
		return try createProvider(for: accountUID)
	}

	public func getBackgroundSessionProvider(with accountUID: String, sessionIdentifier: String) throws -> any CloudProvider {
		if let entry = CloudProviderDBManager.cachedProvider.first(where: {
			$0.accountUID == accountUID && $0.backgroundSessionIdentifier == sessionIdentifier
		}) {
			return entry.provider
		}
		return try createBackgroundSessionProvider(for: accountUID, sessionIdentifier: sessionIdentifier)
	}

	/**
	 Creates and returns a cloud provider for the given `accountUID`.
	 */
	func createProvider(for accountUID: String) throws -> CloudProvider {
		let cloudProviderType = try accountManager.getCloudProviderType(for: accountUID)
		let provider: CloudProvider
		switch cloudProviderType {
		case .dropbox:
			let credential = DropboxCredential(tokenUID: accountUID)
			provider = DropboxCloudProvider(credential: credential, maxPageSize: .max)
		case .googleDrive:
			let credential = GoogleDriveCredential(userID: accountUID)
			provider = try GoogleDriveCloudProvider(credential: credential, maxPageSize: .max)
		case .oneDrive:
			let credential = try OneDriveCredential(with: accountUID)
			provider = try OneDriveCloudProvider(credential: credential, maxPageSize: .max)
		case .pCloud:
			let credential = try PCloudCredential(userID: accountUID)
			let client = PCloud.createClient(with: credential.user)
			provider = try PCloudCloudProvider(client: client)
		case .box:
			let tokenStore = BoxTokenStore()
			let credential = BoxCredential(tokenStorage: tokenStore)
			provider = try BoxCloudProvider(credential: credential, maxPageSize: .max)
		case .webDAV:
			let credential = try getWebDAVCredential(for: accountUID)
			let client = WebDAVClient(credential: credential)
			provider = try WebDAVProvider(with: client, maxPageSize: .max)
		case .localFileSystem:
			guard let rootURL = try LocalFileSystemBookmarkManager.getBookmarkedRootURL(for: accountUID) else {
				throw CloudProviderAccountError.accountNotFoundError
			}
			provider = try LocalFileSystemProvider(rootURL: rootURL, maxPageSize: .max)
		case .s3:
			let credential = try getS3Credential(for: accountUID)
			provider = try S3CloudProvider(credential: credential)
		}
		CloudProviderDBManager.cachedProvider.append(
			.init(
				accountUID: accountUID,
				provider: provider,
				backgroundSessionIdentifier: nil
			)
		)
		return provider
	}

	/**
	 Creates and returns a cloud provider for the given `accountUID` using a background URLSession with the given `sessionIdentifier`.

	 The number of returned items from a `fetchItemList(forFolderAt:pageToken:)` call is limited to 500.
	 This is necessary because otherwise memory limit problems can occur with folders with many items in the `FileProviderExtension` where a background `URLSession` is used.
	 */
	func createBackgroundSessionProvider(for accountUID: String, sessionIdentifier: String) throws -> CloudProvider {
		let cloudProviderType = try accountManager.getCloudProviderType(for: accountUID)
		let provider: CloudProvider

		switch cloudProviderType {
		case .dropbox:
			let credential = DropboxCredential(tokenUID: accountUID)
			provider = DropboxCloudProvider(credential: credential, maxPageSize: maxPageSizeForFileProvider)
		case .googleDrive:
			let credential = GoogleDriveCredential(userID: accountUID)
			provider = try GoogleDriveCloudProvider.withBackgroundSession(credential: credential, maxPageSize: maxPageSizeForFileProvider, sessionIdentifier: sessionIdentifier)
		case .oneDrive:
			let credential = try OneDriveCredential(with: accountUID)
			provider = try OneDriveCloudProvider.withBackgroundSession(credential: credential, maxPageSize: maxPageSizeForFileProvider, sessionIdentifier: sessionIdentifier)
		case .pCloud:
			let credential = try PCloudCredential(userID: accountUID)
			let client = PCloud.createBackgroundClient(with: credential.user, sessionIdentifier: sessionIdentifier)
			provider = try PCloudCloudProvider(client: client)
		case .box:
			let tokenStore = BoxTokenStore()
			let credential = BoxCredential(tokenStorage: tokenStore)
			provider = try BoxCloudProvider.withBackgroundSession(credential: credential, maxPageSize: maxPageSizeForFileProvider, sessionIdentifier: sessionIdentifier)
		case .webDAV:
			let credential = try getWebDAVCredential(for: accountUID)
			let client = WebDAVClient.withBackgroundSession(credential: credential, sessionIdentifier: sessionIdentifier, sharedContainerIdentifier: CryptomatorConstants.appGroupName)
			provider = try WebDAVProvider(with: client, maxPageSize: maxPageSizeForFileProvider)
		case .localFileSystem:
			guard let rootURL = try LocalFileSystemBookmarkManager.getBookmarkedRootURL(for: accountUID) else {
				throw CloudProviderAccountError.accountNotFoundError
			}
			provider = try LocalFileSystemProvider(rootURL: rootURL, maxPageSize: maxPageSizeForFileProvider)
		case .s3:
			let credential = try getS3Credential(for: accountUID)
			provider = try S3CloudProvider.withBackgroundSession(credential: credential, sharedContainerIdentifier: CryptomatorConstants.appGroupName)
		}
		CloudProviderDBManager.cachedProvider.append(
			.init(
				accountUID: accountUID,
				provider: provider,
				backgroundSessionIdentifier: sessionIdentifier
			)
		)
		return provider
	}

	private func getS3Credential(for accountUID: String) throws -> S3Credential {
		guard let credential = S3CredentialManager.shared.getCredential(with: accountUID) else {
			throw CloudProviderAccountError.accountNotFoundError
		}
		return credential
	}

	private func getWebDAVCredential(for accountUID: String) throws -> WebDAVCredential {
		guard let credential = WebDAVCredentialManager.shared.getCredentialFromKeychain(with: accountUID) else {
			throw CloudProviderAccountError.accountNotFoundError
		}
		return credential
	}

	public func providerShouldUpdate(with accountUID: String) {
		CloudProviderDBManager.cachedProvider.removeAll(where: { $0.accountUID == accountUID })
		// call XPCService for FileProvider
	}
}
