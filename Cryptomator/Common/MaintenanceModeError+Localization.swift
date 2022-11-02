//
//  MaintenanceModeError+Localization.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 28.10.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import Foundation

extension MaintenanceModeError: LocalizedError {
	public var errorDescription: String? {
		switch self {
		case .runningCloudTask:
			return LocalizedString.getValue("maintenanceModeError.runningCloudTask")
		}
	}
}
