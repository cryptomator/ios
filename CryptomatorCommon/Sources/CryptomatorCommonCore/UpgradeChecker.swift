//
//  UpgradeChecker.swift
//  CryptomatorCommonCore
//
//  Created by Tobias Hagemann on 20.09.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation

public enum UpgradeChecker {
	public static func isEligibleForUpgrade() -> Bool {
		guard let data = CryptomatorKeychain.upgrade.getAsData("eligibleForUpgrade") as NSData? else {
			return false
		}
		var eligible = false
		data.getBytes(&eligible, length: MemoryLayout<Bool>.size)
		return eligible
	}
}
