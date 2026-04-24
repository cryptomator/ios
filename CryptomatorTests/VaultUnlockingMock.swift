//
//  VaultUnlockingMock.swift
//  CryptomatorTests
//
//  Created by Tobias Hagemann on 21.04.26.
//  Copyright © 2026 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import FileProvider
import Foundation

class VaultUnlockingMock: NSObject, VaultUnlocking {
	var unlockVaultKekCallsCount = 0

	let serviceName = NSFileProviderServiceName.vaultUnlocking

	func unlockVault(kek: [UInt8], reply: @escaping (NSError?) -> Void) {
		unlockVaultKekCallsCount += 1
		reply(nil)
	}

	func unlockVault(rawKey: [UInt8], reply: @escaping (NSError?) -> Void) {
		reply(nil)
	}

	func startBiometricalUnlock() {}

	func endBiometricalUnlock() {}

	func makeListenerEndpoint() throws -> NSXPCListenerEndpoint {
		throw MockError.notMocked
	}
}
