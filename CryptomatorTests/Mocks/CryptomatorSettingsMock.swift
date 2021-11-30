//
//  CryptomatorSettingsMock.swift
//  CryptomatorTests
//
//  Created by Philipp Schmid on 23.11.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import Foundation

class CryptomatorSettingsMock: CryptomatorSettings {
	var trialExpirationDate: Date?
	var debugModeEnabled: Bool = false
	var fullVersionUnlocked: Bool = false
}
