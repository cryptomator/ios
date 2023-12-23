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
import Dependencies
import Foundation

public enum HubAuthenticationFlow {
	case success(Data, [AnyHashable: Any])
	case accessNotGranted
	case needsDeviceRegistration
	case licenseExceeded
	case requiresAccountInitialization(at: URL)
}

public enum CryptomatorHubAuthenticatorError: Error {
	case unexpectedError
	case unexpectedResponse
	case deviceNameAlreadyExists

	case invalidBaseURL
	case invalidDeviceResourceURL
	case missingAccessToken
}

public class CryptomatorHubAuthenticator: HubDeviceRegistering, HubKeyReceiving {
	private static let scheme = "hub+"
	@Dependency(\.cryptomatorHubKeyProvider) private var cryptomatorHubKeyProvider

	public init() {}

	public func receiveKey(authState: OIDAuthState, vaultConfig: UnverifiedVaultConfig) async throws -> HubAuthenticationFlow {
		guard let baseURL = createBaseURL(vaultConfig: vaultConfig) else {
			throw CryptomatorHubAuthenticatorError.invalidBaseURL
		}
		let deviceID = try getDeviceID()
		let url = baseURL.appendingPathComponent("/keys").appendingPathComponent("/\(deviceID)")
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
			return .success(data, httpResponse?.allHeaderFields ?? [:])
		case 402:
			return .licenseExceeded
		case 403, 410:
			return .accessNotGranted
		case 404:
			return .needsDeviceRegistration
		case 449:
			let profileURL = baseURL.appendingPathComponent("/app/profile")
			return .requiresAccountInitialization(at: profileURL)
		default:
			throw CryptomatorHubAuthenticatorError.unexpectedResponse
		}
	}

	public func registerDevice(withName name: String, hubConfig: HubConfig, authState: OIDAuthState, setupCode: String) async throws {
		guard let apiBaseURL = hubConfig.getAPIBaseURL() else {
			// TODO: More specific error
			throw CryptomatorHubAuthenticatorError.invalidBaseURL
		}

		let userDto = try await getUser(apiBaseURL: apiBaseURL, authState: authState)

		let publicKey = try cryptomatorHubKeyProvider.getPublicKey()

		let encryptedUserKeyJWE = try getEncryptedUserKeyJWE(userDto: userDto, setupCode: setupCode, publicKey: publicKey)

		let deviceID = try getDeviceID()
		let derPubKey = publicKey.derRepresentation

		let now = getCurrentDateForDeviceCreation()

		let dto = CreateDeviceDto(id: deviceID,
		                          name: name,
		                          type: "MOBILE",
		                          publicKey: derPubKey.base64EncodedString(),
		                          userPrivateKey: encryptedUserKeyJWE.compactSerializedString,
		                          creationTime: now)

		try await createDevice(dto, apiBaseURL: apiBaseURL, authState: authState)
	}

	private func getUser(apiBaseURL: URL, authState: OIDAuthState) async throws -> UserDTO {
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
		return try JSONDecoder().decode(UserDTO.self, from: data)
	}

	private func getEncryptedUserKeyJWE(userDto: UserDTO, setupCode: String, publicKey: P384.KeyAgreement.PublicKey) throws -> JWE {
		guard let privateKey = userDto.privateKey.data(using: .utf8) else {
			// TODO: Throw proper error
			fatalError()
		}
		let jwe = try JWE(compactSerialization: privateKey)

		let userKey = try JWEHelper.decryptUserKey(jwe: jwe, setupCode: setupCode)

		return try JWEHelper.encryptUserKey(userKey: userKey, deviceKey: publicKey)
	}

	private func getCurrentDateForDeviceCreation() -> String {
		let formatter = ISO8601DateFormatter()
		formatter.timeZone = TimeZone(secondsFromGMT: 0) // Set to UTC
		return formatter.string(from: Date())
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

	func createBaseURL(vaultConfig: UnverifiedVaultConfig) -> URL? {
		guard let keyId = vaultConfig.keyId, keyId.hasPrefix(CryptomatorHubAuthenticator.scheme) else {
			return nil
		}
		let baseURLPath = keyId.deletingPrefix(CryptomatorHubAuthenticator.scheme)
		return URL(string: baseURLPath)
	}

	func getDeviceID() throws -> String {
		let publicKey = try cryptomatorHubKeyProvider.getPublicKey()
		let digest = SHA256.hash(data: publicKey.derRepresentation)
		return digest.data.base16EncodedString
	}

	struct CreateDeviceDto: Codable {
		let id: String
		let name: String
		let type: String
		let publicKey: String
		let userPrivateKey: String
		let creationTime: String
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
		return URL(string: apiBaseUrl)
	}

	func getWebAppURL() -> URL? {
		getAPIBaseURL()?.deletingLastPathComponent().appendingPathComponent("app")
	}
}

private struct UserDTO: Codable {
	let id: String
	let name: String
	let publicKey: String
	let privateKey: String
	let setupCode: String
}
