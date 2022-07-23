//
//  File 2.swift
//
//
//  Created by Philipp Schmid on 22.07.22.
//

import AppAuthCore
import CryptoKit
import CryptomatorCloudAccessCore
import Foundation

public enum HubAuthenticationFlow {
	case receivedExistingKey(Data)
	case accessNotGranted
	case needsDeviceRegistration
}

public protocol HubDeviceRegistering {
	func registerDevice(withName name: String, hubConfig: HubConfig, authState: OIDAuthState) async throws
}

public protocol HubKeyReceiving {
	func receiveKey(authState: OIDAuthState, vaultConfig: UnverifiedVaultConfig) async throws -> HubAuthenticationFlow
}

public enum CryptomatorHubAuthenticatorError: Error {
	case unexpectedError
	case unexpectedResponse
	case deviceNameAlreadyExists
}

public class CryptomatorHubAuthenticator: HubDeviceRegistering, HubKeyReceiving {
	private static let scheme = "hub+"
	public static let shared = CryptomatorHubAuthenticator()

	public func receiveKey(authState: OIDAuthState, vaultConfig: UnverifiedVaultConfig) async throws -> HubAuthenticationFlow {
		guard let baseURL = createBaseURL(vaultConfig: vaultConfig) else {
			fatalError("TODO throw error")
		}
		let deviceID = try getDeviceID()
		let url = baseURL.appendingPathComponent("/keys").appendingPathComponent("/\(deviceID)")
		let (accessToken, _) = try await authState.performAction()
		guard let accessToken = accessToken else {
			fatalError("TODO throw error")
		}
		var urlRequest = URLRequest(url: url)
		urlRequest.allHTTPHeaderFields = ["Authorization": "Bearer \(accessToken)"]
		let (data, response) = try await URLSession.shared.data(with: urlRequest)
		switch (response as? HTTPURLResponse)?.statusCode {
		case 200:
			return .receivedExistingKey(data)
		case 403:
			return .accessNotGranted
		case 404:
			return .needsDeviceRegistration
		default:
			throw CryptomatorHubAuthenticatorError.unexpectedResponse
		}
	}

	public func registerDevice(withName name: String, hubConfig: HubConfig, authState: OIDAuthState) async throws {
		let deviceID = try getDeviceID()
		let publicKey = try CryptomatorHubKeyProvider.shared.getPublicKey()
		let derPubKey: Data
		if #available(iOS 14.0, *) {
			derPubKey = publicKey.derRepresentation
		} else {
			fatalError("TODO: Increase the minimum deployment target or change representation")
		}
		let dto = CreateDeviceDto(id: deviceID, name: name, publicKey: derPubKey.base64URLEncodedString())
		guard let devicesResourceURL = URL(string: hubConfig.devicesResourceUrl) else {
			fatalError("TODO: throw error")
		}
		let keyURL = devicesResourceURL.appendingPathComponent("\(deviceID)")
		var request = URLRequest(url: keyURL)
		request.httpMethod = "PUT"
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		request.httpBody = try JSONEncoder().encode(dto)
		let (accessToken, _) = try await authState.performAction()
		guard let accessToken = accessToken else {
			fatalError("TODO throw error")
		}
		request.allHTTPHeaderFields = ["Authorization": "Bearer \(accessToken)"]
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
		let publicKey = try CryptomatorHubKeyProvider.shared.getPublicKey()
		let digest: SHA256.Digest
		if #available(iOS 14.0, *) {
			digest = SHA256.hash(data: publicKey.derRepresentation)
		} else {
			fatalError("TODO: Increase the minimum deployment target or change representation")
		}
		return digest.data.base16EncodedString
	}

	struct CreateDeviceDto: Codable {
		let id: String
		let name: String
		let publicKey: String
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
