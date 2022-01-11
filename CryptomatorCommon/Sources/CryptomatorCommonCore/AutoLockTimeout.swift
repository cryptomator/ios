//
//  AutoLockTimeout.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 11.01.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import Foundation
public enum AutoLockTimeout: CaseIterable, Codable {
	case off
	case oneMinute
	case twoMinutes
	case fiveMinutes
	case tenMinutes
	case fifteenMinutes
	case thirtyMinutes
	case oneHour
	case never

	public var description: String? {
		if let timeInterval = timeInterval {
			let formatter = DateComponentsFormatter()
			formatter.unitsStyle = .full
			formatter.allowedUnits = [.minute, .hour]
			return formatter.string(from: timeInterval)?.capitalized
		}
		if case .off = self {
			return LocalizedString.getValue("autoLockTimeout.off.description")
		}
		if case .never = self {
			return LocalizedString.getValue("autoLockTimeout.never.description")
		}
		return nil
	}

	var timeInterval: TimeInterval? {
		switch self {
		case .oneMinute:
			return 60
		case .twoMinutes:
			return 120
		case .fiveMinutes:
			return 300
		case .tenMinutes:
			return 600
		case .fifteenMinutes:
			return 900
		case .thirtyMinutes:
			return 1800
		case .oneHour:
			return 3600
		case .off, .never:
			return nil
		}
	}
}
