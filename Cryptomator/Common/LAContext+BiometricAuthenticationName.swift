//
//  LAContext+BiometricAuthenticationName.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 09.08.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import LocalAuthentication

extension LAContext {
	func enrolledBiometricsAuthenticationName() -> String? {
		if canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) {
			switch biometryType {
			case .faceID:
				return NSLocalizedString("common.faceID", comment: "")
			case .touchID:
				return NSLocalizedString("common.touchID", comment: "")
			default:
				return nil
			}
		}
		return nil
	}
}
