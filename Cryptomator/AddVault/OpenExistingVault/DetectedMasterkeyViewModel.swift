//
//  DetectedMasterkeyViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 27.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//
import CryptomatorCloudAccessCore
import Foundation

struct DetectedMasterkeyViewModel {
	let masterkeyPath: CloudPath
	private var vaultName: String {
		let masterkeyParentPath = masterkeyPath.deletingLastPathComponent()
		return masterkeyParentPath.lastPathComponent
	}

	var text: String {
		return String(format: NSLocalizedString("addVault.openExistingVault.detectedMasterkey.text", comment: ""), vaultName)
	}
}
