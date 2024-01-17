//
//  FullVersionChecker.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 02.12.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Dependencies
import Foundation

public protocol FullVersionChecker {
	var isFullVersion: Bool { get }
	var hasExpiredTrial: Bool { get }
}

public enum FullVersionCheckerKey {}

extension FullVersionCheckerKey: TestDependencyKey {
	public static let testValue: FullVersionChecker = FullVersionCheckerMock()
}

public extension DependencyValues {
	var fullVersionChecker: FullVersionChecker {
		get { self[FullVersionCheckerKey.self] }
		set { self[FullVersionCheckerKey.self] = newValue }
	}
}

public class UserDefaultsFullVersionChecker: FullVersionChecker {
	@Dependency(\.cryptomatorSettings) private var cryptomatorSettings

	public static let `default` = UserDefaultsFullVersionChecker()

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
