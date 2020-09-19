//
//  CloudPath+DatabaseValueConvertible.swift
//  CloudAccessPrivate
//
//  Created by Philipp Schmid on 19.09.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import Foundation
import GRDB
extension CloudPath: DatabaseValueConvertible {
	public var databaseValue: DatabaseValue {
		path.databaseValue
	}

	public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> CloudPath? {
		switch dbValue.storage {
		case let .string(string):
			return self.init(string)
		default:
			return nil
		}
	}
}
