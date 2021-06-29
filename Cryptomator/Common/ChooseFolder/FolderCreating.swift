//
//  FolderCreating.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 18.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation

protocol FolderCreating: AnyObject {
	func createdNewFolder(at folderPath: CloudPath)
	func stop()
}
