//
//  CloudProviderType.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 20.10.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Foundation
import GRDB

public enum CloudProviderType: Codable, Equatable, Hashable {
	case box
	case dropbox
	case googleDrive
	case localFileSystem(type: LocalFileSystemType)
	case oneDrive
	case pCloud
	case s3(type: S3Type)
	case webDAV(type: WebDAVType)
}

extension CloudProviderType: DatabaseValueConvertible {
	public var databaseValue: DatabaseValue {
		let jsonEncoder = JSONEncoder()
		guard let data = try? jsonEncoder.encode(self) else {
			return .null
		}
		let string = String(decoding: data, as: UTF8.self)
		return string.databaseValue
	}

	public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Self? {
		guard let string = String.fromDatabaseValue(dbValue) else { return nil }
		let data = Data(string.utf8)
		let jsonDecoder = JSONDecoder()
		return try? jsonDecoder.decode(CloudProviderType.self, from: data)
	}
}

public enum LocalFileSystemType: Codable {
	case custom
	case iCloudDrive
}

public enum WebDAVType: Codable {
	case custom
}

public enum S3Type: Codable {
	case custom
}
