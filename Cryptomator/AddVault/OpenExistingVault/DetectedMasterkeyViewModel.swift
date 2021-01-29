//
//  DetectedMasterkeyViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 27.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation
import CryptomatorCloudAccess
struct DetectedMasterkeyViewModel {
	let masterkeyPath: CloudPath
	private var vaultName: String {
		let masterkeyParentPath = masterkeyPath.deletingLastPathComponent()
		return masterkeyParentPath.lastPathComponent
	}
	var text: String {
		"""
		Cryptomator detected the vault \"\(vaultName)\".
		Would you like to add this vault?
		"""
	}
}
