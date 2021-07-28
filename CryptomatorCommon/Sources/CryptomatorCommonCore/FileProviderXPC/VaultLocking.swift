//
//  VaultLocking.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 23.07.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import FileProvider
import Foundation
@objc public protocol VaultLocking: NSFileProviderServiceSource {
	func lockVault(domainIdentifier: NSFileProviderDomainIdentifier)
	func getIsUnlockedVault(domainIdentifier: NSFileProviderDomainIdentifier, reply: @escaping (Bool) -> Void)
	func getUnlockedVaultDomainIdentifiers(reply: @escaping ([NSFileProviderDomainIdentifier]) -> Void)
}

public enum VaultLockingService {
	public static var name: NSFileProviderServiceName {
		return NSFileProviderServiceName("org.cryptomator.ios.vault-locking")
	}
}
