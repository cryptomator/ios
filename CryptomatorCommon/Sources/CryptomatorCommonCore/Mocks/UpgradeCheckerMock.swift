//
//  UpgradeCheckerMock.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 23.11.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

#if DEBUG
import Foundation

final class UpgradeCheckerMock: UpgradeCheckerProtocol {
	// MARK: - isEligibleForUpgrade

	var isEligibleForUpgradeCallsCount = 0
	var isEligibleForUpgradeCalled: Bool {
		isEligibleForUpgradeCallsCount > 0
	}

	var isEligibleForUpgradeReturnValue: Bool!
	var isEligibleForUpgradeClosure: (() -> Bool)?

	func isEligibleForUpgrade() -> Bool {
		isEligibleForUpgradeCallsCount += 1
		return isEligibleForUpgradeClosure.map({ $0() }) ?? isEligibleForUpgradeReturnValue
	}

	// MARK: - couldBeEligibleForUpgrade

	var couldBeEligibleForUpgradeCallsCount = 0
	var couldBeEligibleForUpgradeCalled: Bool {
		couldBeEligibleForUpgradeCallsCount > 0
	}

	var couldBeEligibleForUpgradeReturnValue: Bool!
	var couldBeEligibleForUpgradeClosure: (() -> Bool)?

	func couldBeEligibleForUpgrade() -> Bool {
		couldBeEligibleForUpgradeCallsCount += 1
		return couldBeEligibleForUpgradeClosure.map({ $0() }) ?? couldBeEligibleForUpgradeReturnValue
	}
}
#endif
