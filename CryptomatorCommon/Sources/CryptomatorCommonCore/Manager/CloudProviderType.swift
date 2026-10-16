//
//  CloudProviderType.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 20.10.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation
import GRDB

public enum CloudProviderType: Codable, Equatable, Hashable, DatabaseValueConvertible, Sendable {
	case box
	case dropbox
	case googleDrive
	case localFileSystem(type: LocalFileSystemType)
	case microsoftGraph(type: MicrosoftGraphType)
	case pCloud
	case s3(type: S3Type)
	case webDAV(type: WebDAVType)
}

public enum LocalFileSystemType: Codable, Sendable {
	case custom
	case iCloudDrive
}

public enum WebDAVType: Codable, Sendable {
	case custom
}

public enum S3Type: Codable, Sendable {
	case custom
}
