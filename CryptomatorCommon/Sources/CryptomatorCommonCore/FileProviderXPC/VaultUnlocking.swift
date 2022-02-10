//
//  VaultUnlocking.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 02.07.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import FileProvider
import Foundation
@objc public protocol VaultUnlocking: NSFileProviderServiceSource {
	// "Because communication over XPC is asynchronous, all methods in the protocol must have a return type of void. If you need to return data, you can define a reply block [...]" see: https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingXPCServices.html
	func unlockVault(kek: [UInt8], reply: @escaping (NSError?) -> Void)
	func startBiometricalUnlock()
	func endBiometricalUnlock()
}

public enum VaultUnlockingService {
	public static var name: NSFileProviderServiceName {
		return NSFileProviderServiceName("org.cryptomator.ios.vault-unlocking")
	}
}
