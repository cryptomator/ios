//
//  CloudProviderType+Localization.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 20.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import Foundation

extension CloudProviderType {
	func localizedString() -> String {
		switch self {
		case .box:
			return "Box"
		case .dropbox:
			return "Dropbox"
		case .googleDrive:
			return "Google Drive"
		case let .localFileSystem(type):
			return type.localizedString()
		case let .microsoftGraph(type):
			return type.localizedString()
		case .pCloud:
			return "pCloud"
		case .s3:
			return "S3"
		case .webDAV:
			return "WebDAV"
		}
	}

	func localizedSecondaryString() -> String? {
		switch self {
		case .box:
			return nil
		case .dropbox:
			return nil
		case .googleDrive:
			return nil
		case .localFileSystem:
			return nil
		case let .microsoftGraph(type):
			return type.localizedSecondaryString()
		case .pCloud:
			return nil
		case .s3:
			return nil
		case .webDAV:
			return nil
		}
	}
}

extension LocalFileSystemType {
	func localizedString() -> String {
		switch self {
		case .custom:
			return LocalizedString.getValue("cloudProviderType.localFileSystem")
		case .iCloudDrive:
			return "iCloud Drive"
		}
	}
}

extension MicrosoftGraphType {
	func localizedString() -> String {
		switch self {
		case .oneDrive:
			return "OneDrive"
		case .sharePoint:
			return "SharePoint"
		}
	}

	func localizedSecondaryString() -> String? {
		switch self {
		case .oneDrive:
			return nil
		case .sharePoint:
			return LocalizedString.getValue("cloudProviderType.sharePoint.secondary")
		}
	}
}
