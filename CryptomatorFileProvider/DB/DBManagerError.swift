//
//  DBManagerError.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 09.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation

enum DBManagerError: Error {
	case missingItemMetadata
	case nonSavedItemMetadata
	case taskNotFound
}
