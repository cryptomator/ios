//
//  VaultUnlockingServiceSourceSnapshotMock.swift
//  FileProviderExtension
//
//  Created by Philipp Schmid on 14.12.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

#if SNAPSHOTS
import Foundation

class VaultUnlockingServiceSourceSnapshotMock: VaultUnlockingServiceSource {
	override func unlockVault(kek: [UInt8], reply: @escaping (Error?) -> Void) {
		FileProviderEnumeratorSnapshotMock.isUnlocked = true
		reply(nil)
	}
}
#endif
