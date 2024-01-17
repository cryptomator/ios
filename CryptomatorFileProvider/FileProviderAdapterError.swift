//
//  FileProviderAdapterError.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 24.06.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Foundation

enum FileProviderAdapterError: Error {
	case unsupportedItemIdentifier
	case folderUploadNotSupported
	case parentFolderNotFound
	case parentItemTypeMismatch
	case unsupportedItemType
}
