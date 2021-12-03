//
//  FullVersionChecker.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 02.12.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation
public protocol FullVersionChecker {
	var isFullVersion: Bool { get }
}

public class UserDefaultsFullVersionChecker: FullVersionChecker {
	public static let shared = UserDefaultsFullVersionChecker(cryptomatorSettings: CryptomatorUserDefaults.shared)
	private let cryptomatorSettings: CryptomatorSettings

	init(cryptomatorSettings: CryptomatorSettings) {
		self.cryptomatorSettings = cryptomatorSettings
	}

	public var isFullVersion: Bool {
		if cryptomatorSettings.fullVersionUnlocked {
			return true
		}
		if let trialExpirationDate = cryptomatorSettings.trialExpirationDate, trialExpirationDate > Date() {
			return true
		} else {
			return false
		}
	}
}
