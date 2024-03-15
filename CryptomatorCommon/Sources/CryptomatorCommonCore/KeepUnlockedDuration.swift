//
//  KeepUnlockedDuration.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 11.01.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import Foundation

public enum KeepUnlockedDuration: CaseIterable, Codable {
	case auto
	case fiveMinutes
	case tenMinutes
	case thirtyMinutes
	case oneHour
	case indefinite

	public var description: String? {
		if let timeInterval = timeInterval {
			let formatter = DateComponentsFormatter()
			formatter.unitsStyle = .full
			formatter.allowedUnits = [.minute, .hour]
			return formatter.string(from: timeInterval)?.capitalized
		}
		if case .auto = self {
			return LocalizedString.getValue("keepUnlockedDuration.auto")
		}
		if case .indefinite = self {
			return LocalizedString.getValue("keepUnlockedDuration.indefinite")
		}
		return nil
	}

	public var shortDisplayName: String? {
		if case .auto = self {
			return LocalizedString.getValue("keepUnlockedDuration.auto.shortDisplayName")
		} else {
			return description
		}
	}

	var timeInterval: TimeInterval? {
		switch self {
		case .fiveMinutes:
			return 300
		case .tenMinutes:
			return 600
		case .thirtyMinutes:
			return 1800
		case .oneHour:
			return 3600
		case .indefinite, .auto:
			return nil
		}
	}
}
