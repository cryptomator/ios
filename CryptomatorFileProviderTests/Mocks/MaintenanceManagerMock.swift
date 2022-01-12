//
//  MaintenanceManagerMock.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 12.01.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorFileProvider
import Foundation

final class MaintenanceManagerMock: MaintenanceManager {
	// MARK: - enableMaintenanceMode

	var enableMaintenanceModeThrowableError: Error?
	var enableMaintenanceModeCallsCount = 0
	var enableMaintenanceModeCalled: Bool {
		enableMaintenanceModeCallsCount > 0
	}

	var enableMaintenanceModeClosure: (() throws -> Void)?

	func enableMaintenanceMode() throws {
		if let error = enableMaintenanceModeThrowableError {
			throw error
		}
		enableMaintenanceModeCallsCount += 1
		try enableMaintenanceModeClosure?()
	}

	// MARK: - disableMaintenanceMode

	var disableMaintenanceModeThrowableError: Error?
	var disableMaintenanceModeCallsCount = 0
	var disableMaintenanceModeCalled: Bool {
		disableMaintenanceModeCallsCount > 0
	}

	var disableMaintenanceModeClosure: (() throws -> Void)?

	func disableMaintenanceMode() throws {
		if let error = disableMaintenanceModeThrowableError {
			throw error
		}
		disableMaintenanceModeCallsCount += 1
		try disableMaintenanceModeClosure?()
	}
}
