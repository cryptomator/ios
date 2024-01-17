//
//  CloudPath+Contains.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 27.10.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation

public extension CloudPath {
	func contains(_ other: CloudPath) -> Bool {
		return pathComponents.starts(with: other.pathComponents)
	}
}
