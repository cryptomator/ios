//
//  CloudPath+Extension.swift
//  CryptomatorIntegrationTests
//
//  Created by Philipp Schmid on 15.09.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import Foundation
extension CloudPath {
	/**
	 Get all partialCloudPaths from the current CloudPath.
	 e.g.: currentCloudPath = "/AAA/BBB/CCC/example.txt"
	 returns the following CloudPaths:
	 "/AAA/", "/AAA/BBB/", "/AAA/BBB/CCC/"

	 - Precondition: startIndex > 1 (default: startIndex = 2)
	 */
	func getPartialCloudPaths(startIndex: Int = 2) -> [CloudPath] {
		precondition(startIndex > 1)
		var subCloudPaths = [CloudPath]()
		var cloudPath = self
		while cloudPath.pathComponents.count > startIndex {
			cloudPath = cloudPath.deletingLastPathComponent()
			subCloudPaths.append(cloudPath)
		}
		subCloudPaths.reverse()
		return subCloudPaths
	}
}
