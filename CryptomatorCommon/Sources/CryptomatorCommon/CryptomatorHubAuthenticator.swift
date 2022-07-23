//
//  CryptomatorHubAuthenticator.swift
//
//
//  Created by Philipp Schmid on 22.07.22.
//

import AppAuth
import Base32
import CryptoKit
import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import UIKit

extension CryptomatorHubAuthenticator: HubAuthenticating {
	private static var currentAuthorizationFlow: OIDExternalUserAgentSession?
	public func authenticate(with hubConfig: HubConfig, from viewController: UIViewController) async throws -> OIDAuthState {
		guard let authorizationEndpoint = URL(string: hubConfig.authEndpoint) else {
			fatalError("TODO: throw error")
		}
		guard let tokenEndpoint = URL(string: hubConfig.tokenEndpoint) else {
			fatalError("TODO: throw error")
		}
		guard let redirectURL = URL(string: "hub.org.cryptomator.ios:/auth") else {
			fatalError("TODO: throw error")
		}
		let configuration = OIDServiceConfiguration(authorizationEndpoint: authorizationEndpoint,
		                                            tokenEndpoint: tokenEndpoint)

		let request = OIDAuthorizationRequest(configuration: configuration, clientId: hubConfig.clientId, scopes: nil, redirectURL: redirectURL, responseType: OIDResponseTypeCode, additionalParameters: nil)
		return try await withCheckedThrowingContinuation({ continuation in
			DispatchQueue.main.async {
				CryptomatorHubAuthenticator.currentAuthorizationFlow =
					OIDAuthState.authState(byPresenting: request, presenting: viewController) { authState, error in
						switch (authState, error) {
						case let (.some(authState), nil):
							continuation.resume(returning: authState)
						case let (nil, .some(error)):
							continuation.resume(throwing: error)
						default:
							continuation.resume(throwing: CryptomatorHubAuthenticatorError.unexpectedError)
						}
					}
			}
		})
	}
}

public protocol HubAuthenticating {
	func authenticate(with hubConfig: HubConfig, from viewController: UIViewController) async throws -> OIDAuthState
}

/*
 public class CryptomatorHubAuthenticator {
 	private static let scheme = "hub+"
 	private static var currentAuthorizationFlow: OIDExternalUserAgentSession?
 	public static func authenticate(with hubConfig: HubConfig, from viewController: UIViewController) async throws -> OIDAuthState {
 		guard let authorizationEndpoint = URL(string: hubConfig.authEndpoint) else {
 			fatalError("TODO: throw error")
 		}
 		guard let tokenEndpoint = URL(string: hubConfig.tokenEndpoint) else {
 			fatalError("TODO: throw error")
 		}
 		guard let redirectURL = URL(string: "hub.org.cryptomator.ios:/auth") else {
 			fatalError("TODO: throw error")
 		}
 		let configuration = OIDServiceConfiguration(authorizationEndpoint: authorizationEndpoint,
 													tokenEndpoint: tokenEndpoint)

 		let request = OIDAuthorizationRequest(configuration: configuration, clientId: hubConfig.clientId, scopes: nil, redirectURL: redirectURL, responseType: OIDResponseTypeCode, additionalParameters: nil)
 		return try await withCheckedThrowingContinuation({ continuation in
 			DispatchQueue.main.async {
 				CryptomatorHubAuthenticator.currentAuthorizationFlow =
 					OIDAuthState.authState(byPresenting: request, presenting: viewController) { authState, error in
 						switch (authState, error) {
 						case let (.some(authState), nil):
 							continuation.resume(returning: authState)
 						case let (nil, .some(error)):
 							continuation.resume(throwing: error)
 						default:
 							continuation.resume(throwing: CryptomatorHubAuthenticatorError.unexpectedError)
 						}
 				}
 			}
 		})
 	}

 	public static func receiveKey(authState: OIDAuthState, vaultConfig: UnverifiedVaultConfig) async throws -> HubAuthenticationFlow {
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

 	static func createBaseURL(vaultConfig: UnverifiedVaultConfig) -> URL? {
 		guard let keyId = vaultConfig.keyId, keyId.hasPrefix(scheme) else {
 			return nil
 		}
 		let baseURLPath =  keyId.deletingPrefix(scheme)
 		return URL(string: baseURLPath)
 	}

 	static func getDeviceID() throws -> String {
 		let publicKey = try CryptomatorHubKeyProvider.shared.getPublicKey()
 		let digest: SHA256.Digest
 		if #available(iOS 14.0, *) {
 			digest = SHA256.hash(data: publicKey.derRepresentation)
 		} else {
 			fatalError("TODO: Increase the minimum deployment target or change representation")
 		}
 		return digest.data.base16EncodedString
 	}

 	public static func registerDevice(withName name: String, hubConfig: HubConfig, authState: OIDAuthState) async throws {
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

 	struct CreateDeviceDto: Codable {
 		let id: String
 		let name: String
 		let publicKey: String
 	}
 }

 extension String {
 	func deletingPrefix(_ prefix: String) -> String {
 		guard self.hasPrefix(prefix) else { return self }
 		return String(self.dropFirst(prefix.count))
 	}
 }
 */
