//
//  CloudProviderType+Localization.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 20.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

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
		case let .localFileSystem(localFileSystemType):
			return localFileSystemType.localizedString()
		case .oneDrive:
			return "OneDrive"
		case .pCloud:
			return "pCloud"
		case .s3:
			return "S3"
		case .webDAV:
			return "WebDAV"
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
