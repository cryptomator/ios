//
//  VaultDetector.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 28.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import CryptomatorCloudAccessCore
import Foundation

class VaultDetector {
	class func getVaultItem(items: [CloudItemMetadata], parentCloudPath: CloudPath) -> VaultDetailItem? {
		if let vaultConfigPath = getVaultConfigCloudPath(items: items) {
			let vaultName = getVaultName(for: vaultConfigPath)
			return VaultDetailItem(name: vaultName, vaultPath: parentCloudPath, isLegacyVault: false)
		} else if let legacyMasterkeyPath = getLegacyMasterkeyPath(items: items) {
			let vaultName = getVaultName(for: legacyMasterkeyPath)
			return VaultDetailItem(name: vaultName, vaultPath: parentCloudPath, isLegacyVault: true)
		} else {
			return nil
		}
	}

	class func getVaultConfigCloudPath(items: [CloudItemMetadata]) -> CloudPath? {
		let vaultConfigItem = items.first(where: { $0.name == "vault.cryptomator" && $0.itemType == .file })
		guard items.contains(where: { $0.name == "d" && $0.itemType == .folder }) else {
			DDLogVerbose("Missing d folder")
			return nil
		}
		return vaultConfigItem?.cloudPath
	}

	class func getLegacyMasterkeyPath(items: [CloudItemMetadata]) -> CloudPath? {
		let masterkeyItem = items.first(where: { $0.name == "masterkey.cryptomator" && $0.itemType == .file })
		guard items.contains(where: { $0.name == "d" && $0.itemType == .folder }) else {
			DDLogVerbose("Missing d folder")
			return nil
		}
		return masterkeyItem?.cloudPath
	}

	class func getVaultName(for cryptomatorFilePath: CloudPath) -> String {
		let parentPath = cryptomatorFilePath.deletingLastPathComponent()
		return parentPath.lastPathComponent
	}
}
