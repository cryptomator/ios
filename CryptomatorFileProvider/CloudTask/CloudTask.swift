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
}
