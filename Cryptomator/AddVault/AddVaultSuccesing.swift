//
//  AddVaultSuccesing.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 01.02.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation

protocol AddVaultSuccesing: AnyObject {
	func showFilesApp(forVaultUID: String)
	func done()
}
