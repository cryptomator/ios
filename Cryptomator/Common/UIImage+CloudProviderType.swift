//
//  UIImage+CloudProviderType.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 07.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CloudAccessPrivateCore
import UIKit
extension UIImage {
	convenience init?(for cloudProviderType: CloudProviderType) {
		switch cloudProviderType {
		case .dropbox:
			self.init(named: "dropbox")
		case .googleDrive:
			self.init(named: "google-drive")
		case .localFileSystem:
			// TODO: Add UIImage
			return nil
		case .webDAV:
			self.init(named: "webdav")
		}
	}
}
