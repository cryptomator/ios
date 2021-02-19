//
//  CloudProviderType+Localization.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 20.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CloudAccessPrivateCore
import Foundation
extension CloudProviderType {
	func localizedString() -> String {
		switch self {
		case .dropbox:
			return "Dropbox"
		case .googleDrive:
			return "Google Drive"
		case .webDAV:
			return "WebDAV"
		case .localFileSystem:
			return NSLocalizedString("common.cloudProviderType.localFileSystem", comment: "")
		}
	}
}
