//
//  MaintenanceModeHelper.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 26.10.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import Foundation

/**
 Helper which allows to perform exclusive operations by executing the operation only after the maintenance mode has been enabled and disables it again after finishing the operation.
 */
@objc public protocol MaintenanceModeHelper {
	func enableMaintenanceMode(reply: @escaping (NSError?) -> Void)
	func disableMaintenanceMode(reply: @escaping (NSError?) -> Void)
}

public extension NSFileProviderServiceName {
	static let maintenanceModeHelper = NSFileProviderServiceName("org.cryptomator.ios.maintenance-mode-helper")
}

public enum MaintenanceModeError: Error {
	case runningCloudTask
}

extension MaintenanceModeHelper {
	func enableMaintenanceMode() async throws {
		return try await withCheckedThrowingContinuation({ (continuation: CheckedContinuation<Void, Error>) -> Void in
			self.enableMaintenanceMode { error in
				if let error = error {
					continuation.resume(throwing: error)
				} else {
					continuation.resume()
				}
			}
		})
	}

	func disableMaintenanceMode() async throws {
		return try await withCheckedThrowingContinuation({ (continuation: CheckedContinuation<Void, Error>) -> Void in
			self.disableMaintenanceMode { error in
				if let error = error {
					continuation.resume(throwing: error)
				} else {
					continuation.resume()
				}
			}
		})
	}
}

public extension MaintenanceModeHelper {
	func executeExclusiveOperation(_ operation: @escaping @Sendable () async throws -> Void) async throws {
		try await enableMaintenanceMode()
		// using do catch for the operation execution as defer does not support async operations making unit tests more flaky
		do {
			try await operation()
		} catch {
			try? await disableMaintenanceMode()
			throw error
		}
		try? await disableMaintenanceMode()
	}
}
