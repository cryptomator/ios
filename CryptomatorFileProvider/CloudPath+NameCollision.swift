//
//  CloudPath+NameCollision.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 18.09.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation

public extension CloudPath {
	func createCollisionCloudPath(conflictResolvingAddition: String) -> CloudPath {
		let pathExtension = self.pathExtension
		let urlWithoutExtension = deletingPathExtension()
		let itemName = urlWithoutExtension.lastPathComponent
		let urlWithoutLastPathComponentPath = urlWithoutExtension.deletingLastPathComponent().path
		return CloudPath(urlWithoutLastPathComponentPath + (urlWithoutLastPathComponentPath == "/" ? "" : "/") + itemName + " (\(conflictResolvingAddition))" + (pathExtension.isEmpty ? "" : ".") + pathExtension)
	}

	func createCollisionCloudPath() -> CloudPath {
		let conflictHash = UUID().uuidString.prefix(5)
		return createCollisionCloudPath(conflictResolvingAddition: String(conflictHash))
	}
}
