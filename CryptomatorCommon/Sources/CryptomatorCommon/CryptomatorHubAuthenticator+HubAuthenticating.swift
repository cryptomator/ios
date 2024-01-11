//
//  CryptomatorHubAuthenticator+HubAuthenticating.swift
//
//
//  Created by Philipp Schmid on 22.07.22.
//

import AppAuth
import Base32
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
	private static var currentAuthorizationFlow: OIDExternalUserAgentSession?

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

extension HubAuthenticatingKey: DependencyKey {
	public static var liveValue: HubAuthenticating = CryptomatorHubAuthenticator()
}
