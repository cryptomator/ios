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
	var hasExpiredTrial: Bool { get }
}

/**
 Use a singleton to inject the full version checker conveniently at several initializers since compilation flags do not work on Swift Package Manager level.
 Be aware that it is needed to set the default value once per app launch (+ also when launching the FileProviderExtension).
 */
public enum GlobalFullVersionChecker {
	public static var `default`: FullVersionChecker!
}

public class UserDefaultsFullVersionChecker: FullVersionChecker {
	public static let `default` = UserDefaultsFullVersionChecker(cryptomatorSettings: CryptomatorUserDefaults.shared)
	private let cryptomatorSettings: CryptomatorSettings

	init(cryptomatorSettings: CryptomatorSettings) {
		self.cryptomatorSettings = cryptomatorSettings
	}

	public var isFullVersion: Bool {
		if cryptomatorSettings.fullVersionUnlocked {
			return true
		}
		if cryptomatorSettings.hasRunningSubscription {
			return true
		}
		if let trialExpirationDate = cryptomatorSettings.trialExpirationDate, trialExpirationDate > Date() {
			return true
		} else {
			return false
		}
	}

	public var hasExpiredTrial: Bool {
		if let trialExpirationDate = cryptomatorSettings.trialExpirationDate, trialExpirationDate <= Date() {
			return true
		} else {
			return false
		}
	}
}

public class AlwaysActivatedPremium: FullVersionChecker {
	public let isFullVersion = true
	public let hasExpiredTrial = false

	public static let `default` = AlwaysActivatedPremium()
}
