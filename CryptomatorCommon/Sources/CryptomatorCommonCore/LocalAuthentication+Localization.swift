//
//  LocalAuthentication+Localization.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 09.08.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import LocalAuthentication

public extension LABiometryType {
	func localizedName() -> String? {
		switch self {
		case .faceID:
			return LocalizedString.getValue("biometryType.faceID")
		case .touchID:
			return LocalizedString.getValue("biometryType.touchID")
		default:
			return nil
		}
	}
}

public extension LAContext {
	func enrolledBiometricsAuthenticationName() -> String? {
		if canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) {
			return biometryType.localizedName()
		}
		return nil
	}
}
