//
//  CryptomatorUserDefaults.swift
//  CryptomatorCommonCore
//
//  Created by Tobias Hagemann on 22.09.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import Dependencies
import Foundation

public protocol CryptomatorSettings {
	var debugModeEnabled: Bool { get set }
	var trialExpirationDate: Date? { get set }
	var fullVersionUnlocked: Bool { get set }
	var hasRunningSubscription: Bool { get set }
}

private enum CryptomatorSettingsKey: DependencyKey {
	#if DEBUG
	static let testValue: CryptomatorSettings = CryptomatorSettingsMock()
	#endif
	static let liveValue: CryptomatorSettings = CryptomatorUserDefaults.shared
}

public extension DependencyValues {
	var cryptomatorSettings: CryptomatorSettings {
		get { self[CryptomatorSettingsKey.self] }
		set { self[CryptomatorSettingsKey.self] = newValue }
	}
}

public class CryptomatorUserDefaults {
	public static let shared = CryptomatorUserDefaults()

	public static let isTestFlightEnvironment = detectTestFlightEnvironment()
	private var defaults = UserDefaults(suiteName: CryptomatorConstants.appGroupName)!

	#if DEBUG
	private static let debugModeEnabledDefaultValue = true
	#else
	private static let debugModeEnabledDefaultValue = false
	#endif

	/**
	  Detects an TestFlight release by checking the last path component of the App Store receipt URL

	  For a normal App Store release the `appStoreReceiptURL` ends with `/receipt` and for a TestFlight release the `appStoreReceiptURL` ends with `/sandboxReceipt`.
	 */
	private static func detectTestFlightEnvironment() -> Bool {
		return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
	}

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
		}
		return property
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

	public var hasRunningSubscription: Bool {
		get { read() ?? false }
		set { write(value: newValue) }
	}
}
