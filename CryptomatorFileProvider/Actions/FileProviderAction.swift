//
//  FileProviderAction.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 03.05.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import Foundation

public enum FileProviderAction: String {
	case retryFailedUpload = "org.cryptomator.ios.fileprovider.retry-failed-upload"
	case retryWaitingUpload = "org.cryptomator.ios.fileprovider.retry-waiting-upload"
	case evictFileFromCache = "org.cryptomator.ios.fileprovider.evict-file-from-cache"
}
