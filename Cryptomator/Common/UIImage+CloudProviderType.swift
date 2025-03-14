//
//  UIImage+CloudProviderType.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 07.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import UIKit

extension UIImage {
	enum State {
		case normal
		case highlighted
	}

	convenience init?(vaultIconFor cloudProviderType: CloudProviderType, state: UIImage.State) {
		var assetName: String
		switch cloudProviderType {
		case .box:
			assetName = "box-vault"
		case .dropbox:
			assetName = "dropbox-vault"
		case .googleDrive:
			assetName = "google-drive-vault"
		case let .localFileSystem(type):
			assetName = UIImage.getVaultIcon(for: type)
		case let .microsoftGraph(type):
			assetName = UIImage.getVaultIcon(for: type)
		case .pCloud:
			assetName = "pcloud-vault"
		case .s3:
			assetName = "s3-vault"
		case .webDAV:
			assetName = "webdav-vault"
		}
		if state == .highlighted {
			assetName += "-selected"
		}
		self.init(named: assetName)
	}

	private static func getVaultIcon(for type: LocalFileSystemType) -> String {
		switch type {
		case .custom:
			return "file-provider-vault"
		case .iCloudDrive:
			return "icloud-drive-vault"
		}
	}

	private static func getVaultIcon(for type: MicrosoftGraphType) -> String {
		switch type {
		case .oneDrive:
			return "onedrive-vault"
		case .sharePoint:
			return "sharepoint-vault"
		}
	}

	convenience init?(storageIconFor cloudProviderType: CloudProviderType) {
		var assetName: String
		switch cloudProviderType {
		case .box:
			assetName = "box"
		case .dropbox:
			assetName = "dropbox"
		case .googleDrive:
			assetName = "google-drive"
		case let .localFileSystem(type):
			assetName = UIImage.getStorageIcon(for: type)
		case let .microsoftGraph(type):
			assetName = UIImage.getStorageIcon(for: type)
		case .pCloud:
			assetName = "pcloud"
		case .s3:
			assetName = "s3"
		case .webDAV:
			assetName = "webdav"
		}
		self.init(named: assetName)
	}

	private static func getStorageIcon(for type: LocalFileSystemType) -> String {
		switch type {
		case .custom:
			return "file-provider"
		case .iCloudDrive:
			return "icloud-drive"
		}
	}

	private static func getStorageIcon(for type: MicrosoftGraphType) -> String {
		switch type {
		case .oneDrive:
			return "onedrive"
		case .sharePoint:
			return "sharepoint"
		}
	}
}
