//
//  HubDeviceRegisteringService.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 19.11.23.
//  Copyright © 2023 Skymatic GmbH. All rights reserved.
//

import AppAuthCore
import CryptomatorCloudAccessCore
import Dependencies
import Foundation
import XCTestDynamicOverlay

public protocol HubDeviceRegistering {
	func registerDevice(withName name: String, hubConfig: HubConfig, authState: OIDAuthState, setupCode: String) async throws
}

private enum HubDeviceRegisteringKey: DependencyKey {
	static var liveValue: HubDeviceRegistering = CryptomatorHubAuthenticator()
	#if DEBUG
	static var testValue: HubDeviceRegistering = UnimplementedHubDeviceRegisteringService()
	#endif
}

extension DependencyValues {
	var hubDeviceRegisteringService: HubDeviceRegistering {
		get { self[HubDeviceRegisteringKey.self] }
		set { self[HubDeviceRegisteringKey.self] = newValue }
	}
}

#if DEBUG
final class UnimplementedHubDeviceRegisteringService: HubDeviceRegistering {
	func registerDevice(withName name: String, hubConfig: HubConfig, authState: OIDAuthState, setupCode: String) async throws {
		XCTFail("\(Self.self).registerDevice is unimplemented.")
	}
}

// MARK: - HubDeviceRegisteringMock -

// swiftlint: disable all
final class HubDeviceRegisteringMock: HubDeviceRegistering {
	// MARK: - registerDevice

	var registerDeviceWithNameHubConfigAuthStateSetupCodeThrowableError: Error?
	var registerDeviceWithNameHubConfigAuthStateSetupCodeCallsCount = 0
	var registerDeviceWithNameHubConfigAuthStateSetupCodeCalled: Bool {
		registerDeviceWithNameHubConfigAuthStateSetupCodeCallsCount > 0
	}

	var registerDeviceWithNameHubConfigAuthStateSetupCodeReceivedArguments: (name: String, hubConfig: HubConfig, authState: OIDAuthState, setupCode: String)?
	var registerDeviceWithNameHubConfigAuthStateSetupCodeReceivedInvocations: [(name: String, hubConfig: HubConfig, authState: OIDAuthState, setupCode: String)] = []
	var registerDeviceWithNameHubConfigAuthStateSetupCodeClosure: ((String, HubConfig, OIDAuthState, String) throws -> Void)?

	func registerDevice(withName name: String, hubConfig: HubConfig, authState: OIDAuthState, setupCode: String) throws {
		if let error = registerDeviceWithNameHubConfigAuthStateSetupCodeThrowableError {
			throw error
		}
		registerDeviceWithNameHubConfigAuthStateSetupCodeCallsCount += 1
		registerDeviceWithNameHubConfigAuthStateSetupCodeReceivedArguments = (name: name, hubConfig: hubConfig, authState: authState, setupCode: setupCode)
		registerDeviceWithNameHubConfigAuthStateSetupCodeReceivedInvocations.append((name: name, hubConfig: hubConfig, authState: authState, setupCode: setupCode))
		try registerDeviceWithNameHubConfigAuthStateSetupCodeClosure?(name, hubConfig, authState, setupCode)
	}
}
// swiftlint: enable all
#endif
