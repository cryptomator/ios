//
//  CryptomatorSettings.swift
//  CryptomatorCommonCore
//
//  Created by Tobias Hagemann on 22.09.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import Foundation

public class CryptomatorSettings {
	public static let shared = CryptomatorSettings()

	private var defaults = UserDefaults(suiteName: CryptomatorConstants.appGroupName)!

	private func read<T>(property: String = #function) -> T? {
		defaults.object(forKey: property) as? T
	}

	private func write<T>(value: T, to property: String = #function) {
		defaults.set(value, forKey: property)
		DDLogDebug("Setting \(property) was written with value \(value)")
	}
}

public extension CryptomatorSettings {
	var showOnboardingAtStartup: Bool {
		get { read() ?? true }
		set { write(value: newValue) }
	}

	var fullVersionUnlocked: Bool {
		get { read() ?? false }
		set { write(value: newValue) }
	}

	var trialExpirationDate: Date? {
		get { read() }
		set { write(value: newValue) }
	}
}
