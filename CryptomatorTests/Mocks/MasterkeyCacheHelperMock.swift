//
//  MasterkeyCacheHelperMock.swift
//  CryptomatorTests
//
//  Created by Philipp Schmid on 12.01.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import Foundation
@testable import CryptomatorCommonCore

final class MasterkeyCacheHelperMock: MasterkeyCacheHelper {
	// MARK: - shouldCacheMasterkey

	var shouldCacheMasterkeyForVaultUIDCallsCount = 0
	var shouldCacheMasterkeyForVaultUIDCalled: Bool {
		shouldCacheMasterkeyForVaultUIDCallsCount > 0
	}

	var shouldCacheMasterkeyForVaultUIDReceivedVaultUID: String?
	var shouldCacheMasterkeyForVaultUIDReceivedInvocations: [String] = []
	var shouldCacheMasterkeyForVaultUIDReturnValue: Bool!
	var shouldCacheMasterkeyForVaultUIDClosure: ((String) -> Bool)?

	func shouldCacheMasterkey(forVaultUID vaultUID: String) -> Bool {
		shouldCacheMasterkeyForVaultUIDCallsCount += 1
		shouldCacheMasterkeyForVaultUIDReceivedVaultUID = vaultUID
		shouldCacheMasterkeyForVaultUIDReceivedInvocations.append(vaultUID)
		return shouldCacheMasterkeyForVaultUIDClosure.map({ $0(vaultUID) }) ?? shouldCacheMasterkeyForVaultUIDReturnValue
	}
}
