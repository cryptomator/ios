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
	func registerDevice(withName name: String, hubConfig: HubConfig, authState: OIDAuthState) async throws
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
	func registerDevice(withName name: String, hubConfig: HubConfig, authState: OIDAuthState) async throws {
		XCTFail("\(Self.self).registerDevice is unimplemented.")
	}
}

// MARK: - HubDeviceRegisteringMock -

// swiftlint: disable all
final class HubDeviceRegisteringMock: HubDeviceRegistering {
	// MARK: - registerDevice

	var registerDeviceWithNameHubConfigAuthStateThrowableError: Error?
	var registerDeviceWithNameHubConfigAuthStateCallsCount = 0
	var registerDeviceWithNameHubConfigAuthStateCalled: Bool {
		registerDeviceWithNameHubConfigAuthStateCallsCount > 0
	}

	var registerDeviceWithNameHubConfigAuthStateReceivedArguments: (name: String, hubConfig: HubConfig, authState: OIDAuthState)?
	var registerDeviceWithNameHubConfigAuthStateReceivedInvocations: [(name: String, hubConfig: HubConfig, authState: OIDAuthState)] = []
	var registerDeviceWithNameHubConfigAuthStateClosure: ((String, HubConfig, OIDAuthState) throws -> Void)?

	func registerDevice(withName name: String, hubConfig: HubConfig, authState: OIDAuthState) throws {
		if let error = registerDeviceWithNameHubConfigAuthStateThrowableError {
			throw error
		}
		registerDeviceWithNameHubConfigAuthStateCallsCount += 1
		registerDeviceWithNameHubConfigAuthStateReceivedArguments = (name: name, hubConfig: hubConfig, authState: authState)
		registerDeviceWithNameHubConfigAuthStateReceivedInvocations.append((name: name, hubConfig: hubConfig, authState: authState))
		try registerDeviceWithNameHubConfigAuthStateClosure?(name, hubConfig, authState)
	}
}
// swiftlint: enable all
#endif
