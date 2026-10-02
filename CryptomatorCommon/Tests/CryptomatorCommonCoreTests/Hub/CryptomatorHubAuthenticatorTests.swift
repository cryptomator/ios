//
//  CryptomatorHubAuthenticatorTests.swift
//  CryptomatorCommonCoreTests
//
//  Created by Tobias Hagemann on 03.09.26.
//  Copyright © 2026 Skymatic GmbH. All rights reserved.
//

import AppAuthCore
import CryptoKit
import Dependencies
import Foundation
import XCTest
@testable import CryptomatorCloudAccessCore
@testable import CryptomatorCommonCore

final class CryptomatorHubAuthenticatorTests: XCTestCase {
	private var hubKeyProviderMock: CryptomatorHubKeyProviderMock!

	override func setUpWithError() throws {
		hubKeyProviderMock = CryptomatorHubKeyProviderMock()
		hubKeyProviderMock.getPublicKeyReturnValue = P384.KeyAgreement.PrivateKey(compactRepresentable: false).publicKey
	}

	// MARK: receiveKey - license headers

	func testReceiveKey_resolvesLicenseHeadersInCanonicalCasing() async throws {
		// GIVEN
		// the hub answers the access-token request with the header casing an HTTP/1.1 server sends
		let hub = StubbedHub(accessTokenHeaderFields: ["Hub-iOS-License": "license.jwt.token", "Hub-Subscription-State": "ACTIVE"])

		// WHEN
		// receiving the key
		let flow = try await receiveKey(from: hub)

		// THEN
		// both header values reach the flow response
		let success = try XCTUnwrap(flow.success)
		XCTAssertEqual(success.iosLicenseToken, "license.jwt.token")
		XCTAssertEqual(success.legacySubscriptionState, "ACTIVE")
	}

	func testReceiveKey_resolvesLicenseHeadersInLowercaseCasing() async throws {
		// GIVEN
		// the hub answers the access-token request with the header casing an HTTP/2 server sends
		let hub = StubbedHub(accessTokenHeaderFields: ["hub-ios-license": "license.jwt.token", "hub-subscription-state": "ACTIVE"])

		// WHEN
		// receiving the key
		let flow = try await receiveKey(from: hub)

		// THEN
		// both header values reach the flow response
		let success = try XCTUnwrap(flow.success)
		XCTAssertEqual(success.iosLicenseToken, "license.jwt.token")
		XCTAssertEqual(success.legacySubscriptionState, "ACTIVE")
	}

	func testReceiveKey_withoutLicenseHeaders() async throws {
		// GIVEN
		// the hub answers the access-token request without any license header
		let hub = StubbedHub()

		// WHEN
		// receiving the key
		let flow = try await receiveKey(from: hub)

		// THEN
		// no value is invented for the absent headers
		let success = try XCTUnwrap(flow.success)
		XCTAssertNil(success.iosLicenseToken)
		XCTAssertNil(success.legacySubscriptionState)
	}

	// MARK: receiveKey - non-success outcomes

	func testReceiveKey_licenseExceeded() async throws {
		let flow = try await receiveKey(from: StubbedHub(accessTokenStatusCode: 402))

		guard case .licenseExceeded = flow else {
			return XCTFail("Expected licenseExceeded, got \(flow)")
		}
	}

	func testReceiveKey_accessNotGranted() async throws {
		let flow = try await receiveKey(from: StubbedHub(accessTokenStatusCode: 403))

		guard case .accessNotGranted = flow else {
			return XCTFail("Expected accessNotGranted, got \(flow)")
		}
	}

	func testReceiveKey_vaultArchived() async throws {
		let flow = try await receiveKey(from: StubbedHub(accessTokenStatusCode: 410))

		guard case .vaultArchived = flow else {
			return XCTFail("Expected vaultArchived, got \(flow)")
		}
	}

	func testReceiveKey_requiresAccountInitialization() async throws {
		let flow = try await receiveKey(from: StubbedHub(accessTokenStatusCode: 449))

		guard case let .requiresAccountInitialization(profileURL) = flow else {
			return XCTFail("Expected requiresAccountInitialization, got \(flow)")
		}
		XCTAssertEqual(profileURL.lastPathComponent, "profile")
	}

	func testReceiveKey_legacyHubVersionThrows() async {
		await assertThrowsIncompatibleHubVersion(StubbedHub(accessTokenStatusCode: 404))
	}

	func testReceiveKey_incompatibleApiLevelThrows() async {
		await assertThrowsIncompatibleHubVersion(StubbedHub(apiLevel: 1))
	}

	func testReceiveKey_needsDeviceRegistration() async throws {
		// the hub does not know this device yet
		let flow = try await receiveKey(from: StubbedHub(userKeyStatusCode: 404))

		guard case .needsDeviceRegistration = flow else {
			return XCTFail("Expected needsDeviceRegistration, got \(flow)")
		}
	}

	func testReceiveKey_unexpectedAccessTokenStatusThrows() async throws {
		await XCTAssertThrowsErrorAsync(try await receiveKey(from: StubbedHub(accessTokenStatusCode: 500))) { error in
			guard case CryptomatorHubAuthenticatorError.unexpectedResponse = error else {
				return XCTFail("Unexpected error: \(error)")
			}
		}
	}

	// MARK: - Internal

	private func receiveKey(from hub: StubbedHub) async throws -> HubAuthenticationFlow {
		let authenticator = CryptomatorHubAuthenticator(load: hub.loader())
		let vaultConfig = try UnverifiedVaultConfig(token: Data(HubTestFixtures.vaultConfigToken.utf8))
		return try await withDependencies({
			$0.cryptomatorHubKeyProvider = self.hubKeyProviderMock
		}, operation: {
			try await authenticator.receiveKey(authState: .stub, vaultConfig: vaultConfig)
		})
	}

	private func assertThrowsIncompatibleHubVersion(_ hub: StubbedHub, file: StaticString = #filePath, line: UInt = #line) async {
		await XCTAssertThrowsErrorAsync(try await receiveKey(from: hub), file: file, line: line) { error in
			guard case CryptomatorHubAuthenticatorError.incompatibleHubVersion = error else {
				return XCTFail("Unexpected error: \(error)", file: file, line: line)
			}
		}
	}

	private func XCTAssertThrowsErrorAsync<T>(_ expression: @autoclosure () async throws -> T,
	                                          file: StaticString = #filePath,
	                                          line: UInt = #line,
	                                          _ errorHandler: (Error) -> Void) async {
		do {
			_ = try await expression()
			XCTFail("Expected an error to be thrown", file: file, line: line)
		} catch {
			errorHandler(error)
		}
	}
}

/// Answers the three requests `receiveKey` makes, and fails the test on any other request.
private struct StubbedHub {
	private static let configPath = "/hub30/api/config"
	private static let accessTokenPath = "/hub30/api/vaults/75af21b7-4849-4558-b05c-de6dc9077a67/access-token"
	private static let devicesPathPrefix = "/hub30/api/devices/"

	var apiLevel = 2
	var accessTokenStatusCode = 200
	var accessTokenHeaderFields: [String: String] = [:]
	var userKeyStatusCode = 200

	func loader(file: StaticString = #filePath, line: UInt = #line) -> CryptomatorHubAuthenticator.DataLoader {
		{ request in
			let url = try XCTUnwrap(request.url, file: file, line: line)
			switch url.path {
			case Self.configPath:
				return try (Data(#"{"apiLevel": \#(apiLevel)}"#.utf8), Self.response(for: url, statusCode: 200, headerFields: [:]))
			case Self.accessTokenPath:
				let body = Data(HubTestFixtures.encryptedVaultKey.utf8)
				return try (body, Self.response(for: url, statusCode: accessTokenStatusCode, headerFields: accessTokenHeaderFields))
			case let path where path.hasPrefix(Self.devicesPathPrefix) && path != Self.devicesPathPrefix:
				let body = try JSONEncoder().encode(["userPrivateKey": HubTestFixtures.encryptedUserKey])
				return try (body, Self.response(for: url, statusCode: userKeyStatusCode, headerFields: [:]))
			default:
				XCTFail("Unexpected request to \(url)", file: file, line: line)
				throw URLError(.unsupportedURL)
			}
		}
	}

	private static func response(for url: URL, statusCode: Int, headerFields: [String: String]) throws -> HTTPURLResponse {
		try XCTUnwrap(HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: headerFields))
	}
}

private extension HubAuthenticationFlow {
	var success: HubAuthenticationFlowSuccess? {
		guard case let .success(success) = self else {
			return nil
		}
		return success
	}
}
