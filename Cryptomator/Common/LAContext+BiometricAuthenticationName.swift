//
//  LAContext+BiometricAuthenticationName.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 09.08.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import LocalAuthentication

extension LAContext {
	func enrolledBiometricsAuthenticationName() -> String? {
		if canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) {
			switch biometryType {
			case .faceID:
				return LocalizedString.getValue("biometryType.faceID")
			case .touchID:
				return LocalizedString.getValue("biometryType.touchID")
			default:
				return nil
			}
		}
		return nil
	}
}
