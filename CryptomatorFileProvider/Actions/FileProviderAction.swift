//
//  FileProviderAction.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 03.05.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import Foundation

public enum FileProviderAction: String {
	case retryUpload = "org.cryptomator.ios.fileprovider.retryUpload"
	case retryWaitingUpload = "org.cryptomator.ios.fileprovider.retryWaitingUpload"
	case evictFileFromCache = "org.cryptomator.ios.fileprovider.evictFileFromCache"
}
