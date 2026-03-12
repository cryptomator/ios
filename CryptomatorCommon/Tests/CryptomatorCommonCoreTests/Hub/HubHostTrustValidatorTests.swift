//
//  HubHostTrustValidatorTests.swift
//  CryptomatorCommonCoreTests
//
//  Created by Tobias Hagemann on 12.03.26.
//  Copyright © 2026 Skymatic GmbH. All rights reserved.
//

import XCTest
@testable import CryptomatorCloudAccessCore
@testable import CryptomatorCommonCore

final class HubHostTrustValidatorTests: XCTestCase {
	// MARK: - Consistency Checks

	func testConsistentURLs() throws {
		let hubConfig = makeHubConfig(
			authEndpoint: "https://auth.example.com/authorize",
			tokenEndpoint: "https://auth.example.com/token",
			apiBaseUrl: "https://hub.example.com/api",
			devicesResourceUrl: "https://hub.example.com/api/devices"
		)
		let vaultBaseURL = try XCTUnwrap(URL(string: "https://hub.example.com/vaults/123"))
		let result = try HubHostTrustValidator.validate(hubConfig: hubConfig, vaultBaseURL: vaultBaseURL, trustedAuthorities: ["https://hub.example.com", "https://auth.example.com"])
		XCTAssertEqual(result, .trusted)
	}

	func testInconsistentHubURLs() throws {
		let hubConfig = makeHubConfig(
			authEndpoint: "https://auth.example.com/authorize",
			tokenEndpoint: "https://auth.example.com/token",
			apiBaseUrl: "https://hub-a.example.com/api",
			devicesResourceUrl: "https://hub-a.example.com/api/devices"
		)
		let vaultBaseURL = try XCTUnwrap(URL(string: "https://hub-b.example.com/vaults/123"))
		XCTAssertThrowsError(try HubHostTrustValidator.validate(hubConfig: hubConfig, vaultBaseURL: vaultBaseURL, trustedAuthorities: [])) { error in
			guard case HubHostTrustError.inconsistentHubAuthority = error else {
				XCTFail("Expected inconsistentHubAuthority, got \(error)")
				return
			}
		}
	}

	func testInconsistentAuthURLs() throws {
		let hubConfig = makeHubConfig(
			authEndpoint: "https://auth-a.example.com/authorize",
			tokenEndpoint: "https://auth-b.example.com/token",
			apiBaseUrl: "https://hub.example.com/api",
			devicesResourceUrl: "https://hub.example.com/api/devices"
		)
		let vaultBaseURL = try XCTUnwrap(URL(string: "https://hub.example.com/vaults/123"))
		XCTAssertThrowsError(try HubHostTrustValidator.validate(hubConfig: hubConfig, vaultBaseURL: vaultBaseURL, trustedAuthorities: [])) { error in
			guard case HubHostTrustError.inconsistentAuthAuthority = error else {
				XCTFail("Expected inconsistentAuthAuthority, got \(error)")
				return
			}
		}
	}

	func testAuthOnDifferentDomainThanHub() throws {
		let hubConfig = makeHubConfig(
			authEndpoint: "https://keycloak.example.com/authorize",
			tokenEndpoint: "https://keycloak.example.com/token",
			apiBaseUrl: "https://hub.example.com/api",
			devicesResourceUrl: "https://hub.example.com/api/devices"
		)
		let vaultBaseURL = try XCTUnwrap(URL(string: "https://hub.example.com/vaults/123"))
		let result = try HubHostTrustValidator.validate(hubConfig: hubConfig, vaultBaseURL: vaultBaseURL, trustedAuthorities: ["https://hub.example.com", "https://keycloak.example.com"])
		XCTAssertEqual(result, .trusted)
	}

	// MARK: - HTTP Blocking

	func testHTTPNotAllowed() throws {
		let hubConfig = makeHubConfig(
			authEndpoint: "https://auth.example.com/authorize",
			tokenEndpoint: "https://auth.example.com/token",
			apiBaseUrl: "http://hub.example.com/api",
			devicesResourceUrl: "http://hub.example.com/api/devices"
		)
		let vaultBaseURL = try XCTUnwrap(URL(string: "http://hub.example.com/vaults/123"))
		XCTAssertThrowsError(try HubHostTrustValidator.validate(hubConfig: hubConfig, vaultBaseURL: vaultBaseURL, trustedAuthorities: [])) { error in
			guard case HubHostTrustError.httpNotAllowed = error else {
				XCTFail("Expected httpNotAllowed, got \(error)")
				return
			}
		}
	}

	func testHostlessURLRejected() throws {
		let hubConfig = makeHubConfig(
			authEndpoint: "https:///authorize",
			tokenEndpoint: "https:///token",
			apiBaseUrl: "https://hub.example.com/api",
			devicesResourceUrl: "https://hub.example.com/api/devices"
		)
		let vaultBaseURL = try XCTUnwrap(URL(string: "https://hub.example.com/vaults/123"))
		XCTAssertThrowsError(try HubHostTrustValidator.validate(hubConfig: hubConfig, vaultBaseURL: vaultBaseURL, trustedAuthorities: [])) { error in
			guard case HubHostTrustError.invalidURL = error else {
				XCTFail("Expected invalidURL, got \(error)")
				return
			}
		}
	}

	func testHTTPLocalhostAllowed() throws {
		let hubConfig = makeHubConfig(
			authEndpoint: "http://localhost:8080/authorize",
			tokenEndpoint: "http://localhost:8080/token",
			apiBaseUrl: "http://localhost:8080/api",
			devicesResourceUrl: "http://localhost:8080/api/devices"
		)
		let vaultBaseURL = try XCTUnwrap(URL(string: "http://localhost:8080/vaults/123"))
		let result = try HubHostTrustValidator.validate(hubConfig: hubConfig, vaultBaseURL: vaultBaseURL, trustedAuthorities: ["http://localhost:8080"])
		XCTAssertEqual(result, .trusted)
	}

	func testHTTPLoopbackIPAllowed() throws {
		let hubConfig = makeHubConfig(
			authEndpoint: "http://127.0.0.1:8080/authorize",
			tokenEndpoint: "http://127.0.0.1:8080/token",
			apiBaseUrl: "http://127.0.0.1:8080/api",
			devicesResourceUrl: "http://127.0.0.1:8080/api/devices"
		)
		let vaultBaseURL = try XCTUnwrap(URL(string: "http://127.0.0.1:8080/vaults/123"))
		let result = try HubHostTrustValidator.validate(hubConfig: hubConfig, vaultBaseURL: vaultBaseURL, trustedAuthorities: ["http://127.0.0.1:8080"])
		XCTAssertEqual(result, .trusted)
	}

	func testHTTPIPv6LoopbackAllowed() throws {
		let hubConfig = makeHubConfig(
			authEndpoint: "http://[::1]:8080/authorize",
			tokenEndpoint: "http://[::1]:8080/token",
			apiBaseUrl: "http://[::1]:8080/api",
			devicesResourceUrl: "http://[::1]:8080/api/devices"
		)
		let vaultBaseURL = try XCTUnwrap(URL(string: "http://[::1]:8080/vaults/123"))
		let result = try HubHostTrustValidator.validate(hubConfig: hubConfig, vaultBaseURL: vaultBaseURL, trustedAuthorities: ["http://::1:8080"])
		XCTAssertEqual(result, .trusted)
	}

	// MARK: - Auto-Trust

	func testCryptomatorCloudAutoTrusted() throws {
		let hubConfig = makeHubConfig(
			authEndpoint: "https://auth.cryptomator.cloud/authorize",
			tokenEndpoint: "https://auth.cryptomator.cloud/token",
			apiBaseUrl: "https://hub.cryptomator.cloud/api",
			devicesResourceUrl: "https://hub.cryptomator.cloud/api/devices"
		)
		let vaultBaseURL = try XCTUnwrap(URL(string: "https://hub.cryptomator.cloud/vaults/123"))
		let result = try HubHostTrustValidator.validate(hubConfig: hubConfig, vaultBaseURL: vaultBaseURL, trustedAuthorities: [])
		XCTAssertEqual(result, .trusted)
	}

	func testCryptomatorCloudExactDomainAutoTrusted() throws {
		let hubConfig = makeHubConfig(
			authEndpoint: "https://cryptomator.cloud/authorize",
			tokenEndpoint: "https://cryptomator.cloud/token",
			apiBaseUrl: "https://cryptomator.cloud/api",
			devicesResourceUrl: "https://cryptomator.cloud/api/devices"
		)
		let vaultBaseURL = try XCTUnwrap(URL(string: "https://cryptomator.cloud/vaults/123"))
		let result = try HubHostTrustValidator.validate(hubConfig: hubConfig, vaultBaseURL: vaultBaseURL, trustedAuthorities: [])
		XCTAssertEqual(result, .trusted)
	}

	func testSimilarDomainNotAutoTrusted() throws {
		let lookalikeDomains = ["notcryptomator.cloud", "cryptomator.cloud.evil.com", "cryptomator.cloudx.com"]
		for domain in lookalikeDomains {
			let hubConfig = makeHubConfig(
				authEndpoint: "https://\(domain)/authorize",
				tokenEndpoint: "https://\(domain)/token",
				apiBaseUrl: "https://\(domain)/api",
				devicesResourceUrl: "https://\(domain)/api/devices"
			)
			let vaultBaseURL = try XCTUnwrap(URL(string: "https://\(domain)/vaults/123"))
			let result = try HubHostTrustValidator.validate(hubConfig: hubConfig, vaultBaseURL: vaultBaseURL, trustedAuthorities: [])
			guard case .userConfirmationRequired = result else {
				XCTFail("Expected userConfirmationRequired for \(domain), got \(result)")
				return
			}
		}
	}

	// MARK: - Trust State

	func testAlreadyTrustedHost() throws {
		let hubConfig = makeHubConfig(
			authEndpoint: "https://auth.example.com/authorize",
			tokenEndpoint: "https://auth.example.com/token",
			apiBaseUrl: "https://hub.example.com/api",
			devicesResourceUrl: "https://hub.example.com/api/devices"
		)
		let vaultBaseURL = try XCTUnwrap(URL(string: "https://hub.example.com/vaults/123"))
		let result = try HubHostTrustValidator.validate(hubConfig: hubConfig, vaultBaseURL: vaultBaseURL, trustedAuthorities: ["https://hub.example.com", "https://auth.example.com"])
		XCTAssertEqual(result, .trusted)
	}

	func testUntrustedHost() throws {
		let hubConfig = makeHubConfig(
			authEndpoint: "https://auth.example.com/authorize",
			tokenEndpoint: "https://auth.example.com/token",
			apiBaseUrl: "https://hub.example.com/api",
			devicesResourceUrl: "https://hub.example.com/api/devices"
		)
		let vaultBaseURL = try XCTUnwrap(URL(string: "https://hub.example.com/vaults/123"))
		let result = try HubHostTrustValidator.validate(hubConfig: hubConfig, vaultBaseURL: vaultBaseURL, trustedAuthorities: [])
		guard case let .userConfirmationRequired(untrusted) = result else {
			XCTFail("Expected userConfirmationRequired")
			return
		}
		XCTAssertEqual(untrusted, ["https://hub.example.com", "https://auth.example.com"])
	}

	func testPartiallyTrustedHost() throws {
		let hubConfig = makeHubConfig(
			authEndpoint: "https://auth.example.com/authorize",
			tokenEndpoint: "https://auth.example.com/token",
			apiBaseUrl: "https://hub.example.com/api",
			devicesResourceUrl: "https://hub.example.com/api/devices"
		)
		let vaultBaseURL = try XCTUnwrap(URL(string: "https://hub.example.com/vaults/123"))
		let result = try HubHostTrustValidator.validate(hubConfig: hubConfig, vaultBaseURL: vaultBaseURL, trustedAuthorities: ["https://hub.example.com"])
		guard case let .userConfirmationRequired(untrusted) = result else {
			XCTFail("Expected userConfirmationRequired")
			return
		}
		XCTAssertEqual(untrusted, ["https://auth.example.com"])
	}

	// MARK: - Authority Extraction

	func testAuthorityDefaultPortOmitted() throws {
		let url = try XCTUnwrap(URL(string: "https://example.com:443/path"))
		XCTAssertEqual(HubHostTrustValidator.authority(from: url), "https://example.com")
	}

	func testAuthorityDefaultHTTPPortOmitted() throws {
		let url = try XCTUnwrap(URL(string: "http://example.com:80/path"))
		XCTAssertEqual(HubHostTrustValidator.authority(from: url), "http://example.com")
	}

	func testAuthorityNonStandardPortIncluded() throws {
		let url = try XCTUnwrap(URL(string: "https://example.com:8443/path"))
		XCTAssertEqual(HubHostTrustValidator.authority(from: url), "https://example.com:8443")
	}

	func testAuthorityCaseInsensitive() throws {
		let url = try XCTUnwrap(URL(string: "HTTPS://Example.COM/path"))
		XCTAssertEqual(HubHostTrustValidator.authority(from: url), "https://example.com")
	}

	func testAuthorityNoScheme() throws {
		let url = try XCTUnwrap(URL(string: "example.com/path"))
		XCTAssertNil(HubHostTrustValidator.authority(from: url))
	}

	// MARK: - apiBaseUrl Fallback

	func testApiBaseUrlNilFallsBackToDevicesResourceUrl() throws {
		let hubConfig = makeHubConfig(
			authEndpoint: "https://auth.example.com/authorize",
			tokenEndpoint: "https://auth.example.com/token",
			apiBaseUrl: nil,
			devicesResourceUrl: "https://hub.example.com/api/devices"
		)
		let vaultBaseURL = try XCTUnwrap(URL(string: "https://hub.example.com/vaults/123"))
		let result = try HubHostTrustValidator.validate(hubConfig: hubConfig, vaultBaseURL: vaultBaseURL, trustedAuthorities: ["https://hub.example.com", "https://auth.example.com"])
		XCTAssertEqual(result, .trusted)
	}

	// MARK: - Helpers

	private func makeHubConfig(authEndpoint: String, tokenEndpoint: String, apiBaseUrl: String?, devicesResourceUrl: String) -> HubConfig {
		HubConfig(clientId: "test-client",
		          authEndpoint: authEndpoint,
		          tokenEndpoint: tokenEndpoint,
		          authSuccessUrl: "https://unused.example.com/success",
		          authErrorUrl: "https://unused.example.com/error",
		          apiBaseUrl: apiBaseUrl,
		          devicesResourceUrl: devicesResourceUrl)
	}
}

extension HubHostTrustResult: Equatable {
	public static func == (lhs: HubHostTrustResult, rhs: HubHostTrustResult) -> Bool {
		switch (lhs, rhs) {
		case (.trusted, .trusted):
			return true
		case let (.userConfirmationRequired(lhsAuthorities), .userConfirmationRequired(rhsAuthorities)):
			return lhsAuthorities == rhsAuthorities
		default:
			return false
		}
	}
}
