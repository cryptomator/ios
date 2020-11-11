//
//  CloudProviderManager.swift
//  CloudAccessPrivateCore
//
//  Created by Philipp Schmid on 20.10.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import Foundation
public class CloudProviderManager {
	static var cachedProvider = [String: CloudProvider]()
	public static let shared = CloudProviderManager(accountManager: CloudProviderAccountManager.shared)
	let accountManager: CloudProviderAccountManager

	init(accountManager: CloudProviderAccountManager) {
		self.accountManager = accountManager
	}

	public func getProvider(with accountUID: String) throws -> CloudProvider {
		if let provider = CloudProviderManager.cachedProvider[accountUID] {
			return provider
		}
		return try createProvider(for: accountUID)
	}

	func createProvider(for accountUID: String) throws -> CloudProvider {
		let cloudProviderType = try accountManager.getCloudProviderType(for: accountUID)
		let provider: CloudProvider
		switch cloudProviderType {
		case .googleDrive:
			let credential = GoogleDriveCredential(with: accountUID)
			provider = GoogleDriveCloudProvider(with: credential)
		case .dropbox:
			let credential = DropboxCredential(tokenUid: accountUID)
			provider = DropboxCloudProvider(with: credential)
		case .webDAV:
			guard let credential = WebDAVAuthenticator.getCredentialFromKeychain(with: accountUID) else {
				throw CloudProviderAccountError.accountNotFoundError
			}
			let client = WebDAVClient(credential: credential, sharedContainerIdentifier: CryptomatorConstants.appGroupName)
			provider = WebDAVProvider(with: client)
		default:
			throw CloudProviderAccountError.accountNotFoundError
		}
		CloudProviderManager.cachedProvider[accountUID] = provider
		return provider
	}

	public static func providerShouldUpdate(with accountUID: String) {
		cachedProvider[accountUID] = nil
		// call XPCService for FileProvider
	}
}
