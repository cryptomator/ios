//
//  VaultUnlocking.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 02.07.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import FileProvider
import Foundation
import Promises

@objc public protocol VaultUnlocking: NSFileProviderServiceSource {
	// "Because communication over XPC is asynchronous, all methods in the protocol must have a return type of void. If you need to return data, you can define a reply block [...]" see: https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingXPCServices.html
	func unlockVault(kek: [UInt8], reply: @escaping (NSError?) -> Void)
	func startBiometricalUnlock()
	func endBiometricalUnlock()

	func unlockVault(rawKey: [UInt8], reply: @escaping (NSError?) -> Void)
}

public extension VaultUnlocking {
	func unlockVault(kek: [UInt8]) -> Promise<Void> {
		return Promise<Void> { fulfill, reject in
			self.unlockVault(kek: kek) { error in
				if let error = error {
					reject(error)
				} else {
					fulfill(())
				}
			}
		}
	}

	func unlockVault(rawKey: [UInt8]) -> Promise<Void> {
		return Promise<Void> { fulfill, reject in
			self.unlockVault(rawKey: rawKey) { error in
				if let error = error {
					reject(error)
				} else {
					fulfill(())
				}
			}
		}
	}
}

public extension NSFileProviderServiceName {
	static let vaultUnlocking = NSFileProviderServiceName("org.cryptomator.ios.vault-unlocking")
}
