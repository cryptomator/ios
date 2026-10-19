//
//  CryptomatorHubAuthenticator+HubAuthenticating.swift
//
//
//  Created by Philipp Schmid on 22.07.22.
//

import AppAuth
import CryptoKit
import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import Dependencies
import UIKit

enum HubAuthenticationError: Error {
	case invalidAuthEndpoint
	case invalidTokenEndpoint
	case invalidRedirectURL
}

extension CryptomatorHubAuthenticator: HubAuthenticating {
	@MainActor private static var currentAuthorizationFlow: OIDExternalUserAgentSession?

	@MainActor
	public func authenticate(with hubConfig: HubConfig, from viewController: UIViewController) async throws -> OIDAuthState {
		guard let authorizationEndpoint = URL(string: hubConfig.authEndpoint) else {
			throw HubAuthenticationError.invalidAuthEndpoint
		}
		guard let tokenEndpoint = URL(string: hubConfig.tokenEndpoint) else {
			throw HubAuthenticationError.invalidTokenEndpoint
		}
		guard let redirectURL = URL(string: "org.cryptomator.ios:/hub/auth") else {
			throw HubAuthenticationError.invalidRedirectURL
		}
		let configuration = OIDServiceConfiguration(authorizationEndpoint: authorizationEndpoint,
		                                            tokenEndpoint: tokenEndpoint)

		let request = OIDAuthorizationRequest(configuration: configuration, clientId: hubConfig.clientId, scopes: nil, redirectURL: redirectURL, responseType: OIDResponseTypeCode, additionalParameters: nil)
		return try await withCheckedThrowingContinuation({ continuation in
			CryptomatorHubAuthenticator.currentAuthorizationFlow =
				OIDAuthState.authState(byPresenting: request, presenting: viewController) { authState, error in
					switch (authState, error) {
					case let (.some(authState), nil):
						// nonisolated(unsafe): AppAuth calls back on the main thread, and the awaiting caller is main-actor isolated
						nonisolated(unsafe) let authState = authState
						continuation.resume(returning: authState)
					case let (nil, .some(error)):
						continuation.resume(throwing: error)
					default:
						continuation.resume(throwing: CryptomatorHubAuthenticatorError.unexpectedError)
					}
				}
		})
	}
}

extension HubAuthenticatingKey: DependencyKey {
	public static let liveValue: HubAuthenticating = CryptomatorHubAuthenticator()
}
