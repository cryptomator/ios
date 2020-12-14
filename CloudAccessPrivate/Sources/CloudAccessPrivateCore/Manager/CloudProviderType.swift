//
//  CloudProviderType.swift
//  CloudAccessPrivateCore
//
//  Created by Philipp Schmid on 20.10.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Foundation
public enum CloudProviderType: String, Codable {
	case googleDrive
	case dropbox
	case webDAV
	case localFileSystem
}
