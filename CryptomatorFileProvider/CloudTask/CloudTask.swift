//
//  CloudTask.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 18.05.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation

protocol CloudTask {
	var itemMetadata: ItemMetadata { get }
	/// Snapshot captured at task construction; survives concurrent local renames of the same row.
	var cloudPath: CloudPath { get }
	var onlineCollisionDisposition: OnlineCollisionDisposition { get }
}

extension CloudTask {
	var onlineCollisionDisposition: OnlineCollisionDisposition {
		return .renameAndRetry
	}
}

/**
 Whether a task may be renamed when the cloud reports that its path is already taken.

 A component inside an imported package may not: its name is user data that a manifest or an internal reference can depend on,
 so an interior collision has to fail the import instead.
 */
enum OnlineCollisionDisposition {
	case renameAndRetry
	case fail
}
