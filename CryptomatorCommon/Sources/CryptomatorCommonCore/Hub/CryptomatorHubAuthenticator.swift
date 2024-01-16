//
//  CryptomatorHubAuthenticator.swift
//	CryptomatorCommonCore
//
//  Created by Philipp Schmid on 22.07.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import AppAuthCore
import CryptoKit
import CryptomatorCloudAccessCore
import CryptomatorCryptoLib
import Dependencies
import Foundation
import JOSESwift

public enum HubAuthenticationFlow {
	case success(HubAuthenticationFlowSuccess)
	case accessNotGranted
	case needsDeviceRegistration
	case licenseExceeded
	case requiresAccountInitialization(at: URL)
}

public struct HubAuthenticationFlowSuccess {
	public let encryptedUserKey: JWE
	public let encryptedVaultKey: JWE
	public let header: [AnyHashable: Any]
}

public enum CryptomatorHubAuthenticatorError: Error {
	case unexpectedError
	case unexpectedResponse
	case deviceNameAlreadyExists

	case unexpectedPrivateKeyFormat
	case invalidVaultConfig
	case invalidHubConfig
	case invalidBaseURL
	case invalidDeviceResourceURL
	case missingAccessToken
	case incompatibleHubVersion
}

public class CryptomatorHubAuthenticator: HubDeviceRegistering, HubKeyReceiving {
	private static let scheme = "hub+"
	private static let minimumHubVersion = 2
	@Dependency(\.cryptomatorHubKeyProvider) private var cryptomatorHubKeyProvider

	public init() {}

	public func receiveKey(authState: OIDAuthState, vaultConfig: UnverifiedVaultConfig) async throws -> HubAuthenticationFlow {
		guard let hubConfig = vaultConfig.allegedHubConfig, let vaultBaseURL = getVaultBaseURL(from: vaultConfig) else {
			throw CryptomatorHubAuthenticatorError.invalidVaultConfig
		}

		guard let apiBaseURL = hubConfig.getAPIBaseURL(), let webAppURL = hubConfig.getWebAppURL() else {
			throw CryptomatorHubAuthenticatorError.invalidHubConfig
		}

		guard try await hubInstanceHasMinimumAPILevel(of: Self.minimumHubVersion, apiBaseURL: apiBaseURL, authState: authState) else {
			throw CryptomatorHubAuthenticatorError.incompatibleHubVersion
		}

		let retrieveMasterkeyResponse = try await getVaultMasterKey(vaultBaseURL: vaultBaseURL,
		                                                            authState: authState,
		                                                            webAppURL: webAppURL)

		let encryptedVaultKey: String
		let unlockHeader: [AnyHashable: Any]
		switch retrieveMasterkeyResponse {
		case let .success(key, header):
			encryptedVaultKey = key
			unlockHeader = header
		case .accessNotGranted:
			return .accessNotGranted
		case .licenseExceeded:
			return .licenseExceeded
		case let .requiresAccountInitialization(profileURL):
			return .requiresAccountInitialization(at: profileURL)
		case .legacyHubVersion:
			throw CryptomatorHubAuthenticatorError.incompatibleHubVersion
		}

		let retrieveUserPrivateKeyResponse = try await getUserKey(apiBaseURL: apiBaseURL, authState: authState)

		let encryptedUserKey: String
		switch retrieveUserPrivateKeyResponse {
		case let .unlockedSucceeded(deviceDto):
			encryptedUserKey = deviceDto.userPrivateKey
		case .deviceSetup:
			return .needsDeviceRegistration
		}

		let encryptedUserKeyJWE = try JWE(compactSerialization: encryptedUserKey)
		let encryptedVaultKeyJWE = try JWE(compactSerialization: encryptedVaultKey)

		return .success(.init(encryptedUserKey: encryptedUserKeyJWE, encryptedVaultKey: encryptedVaultKeyJWE, header: unlockHeader))
	}

	/**
	 Registers a new device.

	 Registers a new mobile device at the Hub instance derived from the `hubConfig` with the given `name`.

	 The device registration consists of two requests:

	 1. Request the encrypted user key which can be decrypted by using the `setupCode`.
	 2. Send a Create Device request to the Hub instance which contains the user key encrypted with the device key pair.
	 */
	public func registerDevice(withName name: String,
	                           hubConfig: HubConfig,
	                           authState: OIDAuthState,
	                           setupCode: String) async throws {
		guard let apiBaseURL = hubConfig.getAPIBaseURL() else {
			throw CryptomatorHubAuthenticatorError.invalidBaseURL
		}

		let userDto = try await getUser(apiBaseURL: apiBaseURL, authState: authState)

		let publicKey = try cryptomatorHubKeyProvider.getPublicKey()

		let encryptedUserKeyJWE = try getEncryptedUserKeyJWE(userDto: userDto, setupCode: setupCode, publicKey: publicKey)

		let deviceID = try getDeviceID()
		let derPubKey = publicKey.derRepresentation

		let now = ISO8601DateFormatter().string(from: Date())

		let dto = CreateDeviceDto(id: deviceID,
		                          name: name,
		                          type: "MOBILE",
		                          publicKey: derPubKey.base64EncodedString(),
		                          userPrivateKey: encryptedUserKeyJWE.compactSerializedString,
		                          creationTime: now)

		try await createDevice(dto, apiBaseURL: apiBaseURL, authState: authState)
	}

	private func getUser(apiBaseURL: URL, authState: OIDAuthState) async throws -> UserDto {
		let url = apiBaseURL.appendingPathComponent("users/me")
		let (accessToken, _) = try await authState.performAction()
		guard let accessToken = accessToken else {
			throw CryptomatorHubAuthenticatorError.missingAccessToken
		}
		var request = URLRequest(url: url)
		request.allHTTPHeaderFields = ["Authorization": "Bearer \(accessToken)"]
		let (data, response) = try await URLSession.shared.data(with: request)
		let httpResponse = response as? HTTPURLResponse
		guard httpResponse?.statusCode == 200 else {
			throw CryptomatorHubAuthenticatorError.unexpectedResponse
		}
		return try JSONDecoder().decode(UserDto.self, from: data)
	}

	private func getEncryptedUserKeyJWE(userDto: UserDto, setupCode: String, publicKey: P384.KeyAgreement.PublicKey) throws -> JWE {
		guard let privateKey = userDto.privateKey.data(using: .utf8) else {
			throw CryptomatorHubAuthenticatorError.unexpectedPrivateKeyFormat
		}
		let jwe = try JWE(compactSerialization: privateKey)

		let userKey = try JWEHelper.decryptUserKey(jwe: jwe, setupCode: setupCode)

		return try JWEHelper.encryptUserKey(userKey: userKey, deviceKey: publicKey)
	}

	private func createDevice(_ dto: CreateDeviceDto, apiBaseURL: URL, authState: OIDAuthState) async throws {
		let deviceResourceURL = apiBaseURL.appendingPathComponent("devices")
		let deviceURL = deviceResourceURL.appendingPathComponent(dto.id)

		var request = URLRequest(url: deviceURL)
		request.httpMethod = "PUT"
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		request.httpBody = try JSONEncoder().encode(dto)

		let (accessToken, _) = try await authState.performAction()
		guard let secondAccessToken = accessToken else {
			throw CryptomatorHubAuthenticatorError.missingAccessToken
		}
		request.allHTTPHeaderFields = ["Authorization": "Bearer \(secondAccessToken)"]

		let (_, response) = try await URLSession.shared.data(with: request)

		switch (response as? HTTPURLResponse)?.statusCode {
		case 201:
			break
		case 409:
			throw CryptomatorHubAuthenticatorError.deviceNameAlreadyExists
		default:
			throw CryptomatorHubAuthenticatorError.unexpectedResponse
		}
	}

	private func getVaultBaseURL(from vaultConfig: UnverifiedVaultConfig) -> URL? {
		guard let keyId = vaultConfig.keyId, keyId.hasPrefix(CryptomatorHubAuthenticator.scheme) else {
			return nil
		}
		let baseURLPath = keyId.deletingPrefix(CryptomatorHubAuthenticator.scheme)
		return URL(string: baseURLPath)
	}

	private func getDeviceID() throws -> String {
		let publicKey = try cryptomatorHubKeyProvider.getPublicKey()
		let digest = SHA256.hash(data: publicKey.derRepresentation)
		return digest.data.base16EncodedString
	}

	/**
	 Checks if the Hub instance at `apiBaseURL` has at least the API level of `minimumLevel`.

	 - Note: The legacy Hub which is not supported returns a 0.
	 */
	private func hubInstanceHasMinimumAPILevel(of minimumLevel: Int, apiBaseURL: URL, authState: OIDAuthState) async throws -> Bool {
		let url = apiBaseURL.appendingPathComponent("config")
		let (accessToken, _) = try await authState.performAction()
		guard let accessToken = accessToken else {
			throw CryptomatorHubAuthenticatorError.missingAccessToken
		}
		var request = URLRequest(url: url)
		request.allHTTPHeaderFields = ["Authorization": "Bearer \(accessToken)"]
		let (data, response) = try await URLSession.shared.data(with: request)

		guard (response as? HTTPURLResponse)?.statusCode == 200 else {
			throw CryptomatorHubAuthenticatorError.unexpectedResponse
		}
		let config = try JSONDecoder().decode(APIConfigDto.self, from: data)
		return config.apiLevel >= minimumLevel
	}

	private func getVaultMasterKey(vaultBaseURL: URL, authState: OIDAuthState, webAppURL: URL) async throws -> RetrieveVaultMasterkeyEncryptedForUserResponse {
		let url = vaultBaseURL.appendingPathComponent("access-token")
		let (accessToken, _) = try await authState.performAction()
		guard let accessToken = accessToken else {
			throw CryptomatorHubAuthenticatorError.missingAccessToken
		}
		var urlRequest = URLRequest(url: url)
		urlRequest.allHTTPHeaderFields = ["Authorization": "Bearer \(accessToken)"]
		let (data, response) = try await URLSession.shared.data(with: urlRequest)
		let httpResponse = response as? HTTPURLResponse
		switch httpResponse?.statusCode {
		case 200:
			guard let body = String(data: data, encoding: .utf8) else {
				throw CryptomatorHubAuthenticatorError.unexpectedResponse
			}
			return .success(encryptedVaultKey: body, header: httpResponse?.allHeaderFields ?? [:])
		case 402:
			return .licenseExceeded
		case 403, 410:
			return .accessNotGranted
		case 404:
			return .legacyHubVersion
		case 449:
			let profileURL = webAppURL.appendingPathComponent("profile")
			return .requiresAccountInitialization(at: profileURL)
		default:
			throw CryptomatorHubAuthenticatorError.unexpectedResponse
		}
	}

	private func getUserKey(apiBaseURL: URL, authState: OIDAuthState) async throws -> RetrieveUserEncryptedPKResponse {
		let deviceID = try getDeviceID()
		let url = apiBaseURL.appendingPathComponent("devices").appendingPathComponent(deviceID)
		let (accessToken, _) = try await authState.performAction()
		guard let accessToken = accessToken else {
			throw CryptomatorHubAuthenticatorError.missingAccessToken
		}
		var urlRequest = URLRequest(url: url)
		urlRequest.allHTTPHeaderFields = ["Authorization": "Bearer \(accessToken)"]
		let (data, response) = try await URLSession.shared.data(with: urlRequest)
		let httpResponse = response as? HTTPURLResponse

		switch httpResponse?.statusCode {
		case 200:
			return try .unlockedSucceeded(JSONDecoder().decode(DeviceDto.self, from: data))
		case 404:
			return .deviceSetup
		default:
			throw CryptomatorHubAuthenticatorError.unexpectedResponse
		}
	}

	struct CreateDeviceDto: Codable {
		let id: String
		let name: String
		let type: String
		let publicKey: String
		let userPrivateKey: String
		let creationTime: String
	}

	private struct APIConfigDto: Codable {
		let apiLevel: Int
	}

	private enum RetrieveUserEncryptedPKResponse {
		// 200
		case unlockedSucceeded(DeviceDto)
		// 404
		case deviceSetup
	}

	private enum RetrieveVaultMasterkeyEncryptedForUserResponse {
		// 200
		case success(encryptedVaultKey: String, header: [AnyHashable: Any])
		// 403, 410
		case accessNotGranted
		// 402
		case licenseExceeded
		// 449
		case requiresAccountInitialization(at: URL)
		// 404
		case legacyHubVersion
	}

	private struct DeviceDto: Codable {
		let userPrivateKey: String
	}
}

extension URLSession {
	@available(iOS, deprecated: 15.0, message: "This extension is no longer necessary. Use API built into SDK")
	func data(with request: URLRequest) async throws -> (Data, URLResponse) {
		try await withCheckedThrowingContinuation { continuation in
			let task = self.dataTask(with: request) { data, response, error in
				guard let data = data, let response = response else {
					let error = error ?? URLError(.badServerResponse)
					return continuation.resume(throwing: error)
				}

				continuation.resume(returning: (data, response))
			}

			task.resume()
		}
	}
}

extension Digest {
	var bytes: [UInt8] { Array(makeIterator()) }
	var data: Data { Data(bytes) }
}

extension OIDAuthState {
	func performAction() async throws -> (String?, String?) {
		try await withCheckedThrowingContinuation({ continuation in
			performAction { accessToken, idToken, error in
				if let error = error {
					continuation.resume(throwing: error)
				} else {
					continuation.resume(returning: (accessToken, idToken))
				}
			}
		})
	}
}

extension String {
	func deletingPrefix(_ prefix: String) -> String {
		guard hasPrefix(prefix) else { return self }
		return String(dropFirst(prefix.count))
	}
}

extension HubConfig {
	func getAPIBaseURL() -> URL? {
		if let apiBaseUrl {
			return URL(string: apiBaseUrl)
		}
		guard let deviceResourceURL = URL(string: devicesResourceUrl) else {
			return nil
		}
		return deviceResourceURL.deletingLastPathComponent()
	}

	func getWebAppURL() -> URL? {
		getAPIBaseURL()?.deletingLastPathComponent().appendingPathComponent("app")
	}
}

private struct UserDto: Codable {
	let id: String
	let name: String
	let publicKey: String
	let privateKey: String
	let setupCode: String
}
