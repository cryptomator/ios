//
//  FolderChoosing.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 20.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore

protocol FolderChoosing: AnyObject {
	func showItems(for path: CloudPath)
	func close()
	func chooseItem(_ item: Item)
	func showCreateNewFolder(parentPath: CloudPath)
	func handleError(error: Error)
}

protocol Item {
	var path: CloudPath { get }
}

struct Folder: Item {
	let path: CloudPath
}
