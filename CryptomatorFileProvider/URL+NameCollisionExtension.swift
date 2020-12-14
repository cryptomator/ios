//
//  URL+NameCollisionExtension.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 10.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Foundation

public extension URL {
	func createCollisionURL(conflictResolvingAddition: String) -> URL {
		precondition(isFileURL)

		let pathExtension = self.pathExtension
		let urlWithoutExtension = deletingPathExtension()
		let itemName = urlWithoutExtension.lastPathComponent
		let urlWithoutLastPathComponentPath = urlWithoutExtension.deletingLastPathComponent().path

		return URL(fileURLWithPath: urlWithoutLastPathComponentPath + (urlWithoutLastPathComponentPath == "/" ? "" : "/") + itemName + " (\(conflictResolvingAddition))" + (pathExtension.isEmpty ? "" : ".") + pathExtension, isDirectory: hasDirectoryPath)
	}

	func createCollisionURL() -> URL {
		precondition(isFileURL)
		let conflictHash = UUID().uuidString.prefix(5)
		return createCollisionURL(conflictResolvingAddition: String(conflictHash))
	}
}
