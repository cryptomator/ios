//
//  ItemStatus.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 25.06.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Foundation

public enum ItemStatus: String, Codable {
	case isUploading
	case isUploaded
	case uploadError
	case isDownloading
	case downloadError
}
