//
//  MaintenanceModeHelperMock.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 26.10.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

#if DEBUG
import Foundation

final class MaintenanceModeHelperMock: MaintenanceModeHelper {
	// MARK: - enableMaintenanceMode

	var enableMaintenanceModeReplyCallsCount = 0
	var enableMaintenanceModeReplyCalled: Bool {
		enableMaintenanceModeReplyCallsCount > 0
	}

	var enableMaintenanceModeReplyReceivedReply: ((NSError?) -> Void)?
	var enableMaintenanceModeReplyReceivedInvocations: [(NSError?) -> Void] = []
	var enableMaintenanceModeReplyClosure: ((@escaping (NSError?) -> Void) -> Void)?

	func enableMaintenanceMode(reply: @escaping (NSError?) -> Void) {
		enableMaintenanceModeReplyCallsCount += 1
		enableMaintenanceModeReplyReceivedReply = reply
		enableMaintenanceModeReplyReceivedInvocations.append(reply)
		enableMaintenanceModeReplyClosure?(reply)
	}

	// MARK: - disableMaintenanceMode

	var disableMaintenanceModeReplyCallsCount = 0
	var disableMaintenanceModeReplyCalled: Bool {
		disableMaintenanceModeReplyCallsCount > 0
	}

	var disableMaintenanceModeReplyReceivedReply: ((NSError?) -> Void)?
	var disableMaintenanceModeReplyReceivedInvocations: [(NSError?) -> Void] = []
	var disableMaintenanceModeReplyClosure: ((@escaping (NSError?) -> Void) -> Void)?

	func disableMaintenanceMode(reply: @escaping (NSError?) -> Void) {
		disableMaintenanceModeReplyCallsCount += 1
		disableMaintenanceModeReplyReceivedReply = reply
		disableMaintenanceModeReplyReceivedInvocations.append(reply)
		disableMaintenanceModeReplyClosure?(reply)
	}
}

#endif
