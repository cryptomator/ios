//
//  CryptomatorUserDefaults.swift
//  CryptomatorCommonCore
//
//  Created by Tobias Hagemann on 22.09.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import Foundation

public protocol CryptomatorSettings {
	var debugModeEnabled: Bool { get set }
	var trialExpirationDate: Date? { get set }
	var fullVersionUnlocked: Bool { get set }
}

public class CryptomatorUserDefaults {
	public static let shared = CryptomatorUserDefaults()

	private var defaults = UserDefaults(suiteName: CryptomatorConstants.appGroupName)!

	private static let isTestFlightEnvironment = ProcessInfo.processInfo.environment["TESTFLIGHT"] == "1"
	#if DEBUG
	private static let debugModeEnabledDefaultValue = true
	#else
	private static let debugModeEnabledDefaultValue = false
	#endif

	private func read<T>(property: String = #function) -> T? {
		return defaults.object(forKey: key(from: property)) as? T
	}

	private func write<T>(value: T, to property: String = #function) {
		defaults.set(value, forKey: key(from: property))
		DDLogDebug("Setting \(property) was written with value \(value)")
	}

	private func write<T>(value: T?, to property: String = #function) {
		if let value = value {
			write(value: value, to: property)
		} else {
			defaults.removeObject(forKey: key(from: property))
			DDLogDebug("Setting \(property) was removed")
		}
	}

	private func key(from property: String) -> String {
		if CryptomatorUserDefaults.isTestFlightEnvironment {
			return "\(property)-TestFlight"
		} else {
			return property
		}
	}
}

extension CryptomatorUserDefaults: CryptomatorSettings {
	public var showOnboardingAtStartup: Bool {
		get { read() ?? true }
		set { write(value: newValue) }
	}

	public var showedTrialExpiredAtStartup: Bool {
		get { read() ?? false }
		set { write(value: newValue) }
	}

	public var fullVersionUnlocked: Bool {
		get { read() ?? false }
		set { write(value: newValue) }
	}

	public var trialExpirationDate: Date? {
		get { read() }
		set { write(value: newValue) }
	}

	public var debugModeEnabled: Bool {
		get { read() ?? CryptomatorUserDefaults.debugModeEnabledDefaultValue }
		set { write(value: newValue) }
	}
}
