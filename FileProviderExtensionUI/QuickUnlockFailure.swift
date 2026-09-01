//
//  QuickUnlockFailure.swift
//  FileProviderExtensionUI
//
//  Created by Tobias Hagemann on 01.09.26.
//  Copyright © 2026 Skymatic GmbH. All rights reserved.
//

import Foundation
import LocalAuthentication

/**
 What to do after a biometric unlock failed.

 The quick unlock has nothing else on screen, thus anything but `report` leaves the user without a visible result. Closing it is therefore correct only when the user chose to stop.
 */
enum QuickUnlockFailure: Equatable {
	/// The user asked for the password, or biometric authentication is unavailable on this device.
	case fallBackToPassword
	/// The biometric authentication ended for a reason the user does not need explained, e.g. a cancellation or a failed match.
	case dismiss
	/// The unlock failed for a reason the user must see, e.g. an expired cloud session.
	case report

	init(error: Error) {
		guard let laError = error as? LAError else {
			self = .report
			return
		}
		switch laError.code {
		case .userFallback, .biometryLockout, .biometryNotAvailable, .biometryNotEnrolled, .passcodeNotSet, .notInteractive, .invalidContext:
			self = .fallBackToPassword
		default:
			self = .dismiss
		}
	}
}
