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
	case googleDrive
	case dropbox
	case oneDrive
	case webDAV(type: WebDAVType)
	case localFileSystem(type: LocalFileSystemType)
}

extension CloudProviderType: DatabaseValueConvertible {
	public var databaseValue: DatabaseValue {
		let jsonEncoder = JSONEncoder()
		guard let data = try? jsonEncoder.encode(self) else {
			return .null
		}
		let string = String(data: data, encoding: .utf8)
		return string?.databaseValue ?? .null
	}

	public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Self? {
		guard let string = String.fromDatabaseValue(dbValue) else { return nil }
		guard let data = string.data(using: .utf8) else { return nil }
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
