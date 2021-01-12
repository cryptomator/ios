//
//  UIImage+CloudProviderType.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 07.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CloudAccessPrivateCore
import UIKit

enum State {
	case normal
	case highlighted
}

extension UIImage {
	convenience init?(for cloudProviderType: CloudProviderType, state: State) {
		var assetName: String
		switch cloudProviderType {
		case .dropbox:
			assetName = "dropbox"
		case .googleDrive:
			assetName = "google-drive"
		case .localFileSystem:
			assetName = "file-provider"
		case .webDAV:
			assetName = "webdav"
		}
		if state == .highlighted {
			assetName += "-selected"
		}
		self.init(named: assetName)
	}
}
