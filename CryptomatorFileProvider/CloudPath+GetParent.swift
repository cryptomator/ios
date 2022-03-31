//
//  CloudPath+GetParent.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 31.03.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation

extension CloudPath {
	/// Returns the parent of the current path. Returns nil if the current path is already the root path.
	func getParent() -> CloudPath? {
		if path == "/" {
			return nil
		}
		return deletingLastPathComponent()
	}
}
