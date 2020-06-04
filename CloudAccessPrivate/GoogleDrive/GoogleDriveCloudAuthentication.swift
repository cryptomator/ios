//
//  GoogleDriveCloudAuthentication.swift
//  CloudAccessPrivate
//
//  Created by Philipp Schmid on 24.04.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import AppAuth
import CryptomatorCloudAccess
import Foundation
import GoogleAPIClientForREST
import GTMAppAuth
import Promises

public class GoogleDriveCloudAuthentication: CloudAuthentication {
	private let keychainItemName = "GoogleDriveAuth"
	let scopes = [kGTLRAuthScopeDrive]
	public static var currentAuthorizationFlow: OIDExternalUserAgentSession?
	public var authorization: GTMAppAuthFetcherAuthorization?

	public init() {
		self.authorization = GTMAppAuthFetcherAuthorization(fromKeychainForName: keychainItemName)
	}

	public func authenticate(from viewController: UIViewController) -> Promise<Void> {
		return createAuthorizationServiceForGoogle().then { configuration in
			self.getAuthState(for: configuration, with: viewController)
		}.then { authState in
			let authorization = GTMAppAuthFetcherAuthorization(authState: authState)
			self.authorization = authorization
			GTMAppAuthFetcherAuthorization.save(authorization, toKeychainForName: self.keychainItemName)
			return Promise(())
		}
	}

	public func isAuthenticated() -> Promise<Bool> {
		guard let canAuthorize = authorization?.canAuthorize() else {
			return Promise(false)
		}
		return Promise(canAuthorize)
	}

	public func getUsername() -> Promise<String> {
		isAuthenticated().then { authenticated in
			if !authenticated {
				return Promise(CloudAuthenticationError.notAuthenticated)
			}
			guard let userEmail = self.authorization?.userEmail else {
				return Promise(CloudAuthenticationError.noUsername)
			}
			return Promise(userEmail)
		}
	}

	public func deauthenticate() -> Promise<Void> {
		GTMAppAuthFetcherAuthorization.removeFromKeychain(forName: keychainItemName)
		authorization = nil
		return Promise(())
	}

	private func createAuthorizationServiceForGoogle() -> Promise<OIDServiceConfiguration> {
		let issuer = URL(string: "https://accounts.google.com")!
		return Promise<OIDServiceConfiguration> { fulfill, reject in
			OIDAuthorizationService.discoverConfiguration(forIssuer: issuer) { configuration, error in
				if error != nil {
					return reject(error!)
				}
				guard let configuration = configuration else {
					return reject(GoogleDriveError.unexpectedError) // MARK: This should never occur
				}
				fulfill(configuration)
			}
		}
	}

	private func getAuthState(for configuration: OIDServiceConfiguration, with presentingViewController: UIViewController) -> Promise<OIDAuthState> {
		let request = OIDAuthorizationRequest(configuration: configuration, clientId: CloudAccessSecrets.googleDriveClientId, scopes: scopes, redirectURL: CloudAccessSecrets.googleDriveRedirectURL!, responseType: OIDResponseTypeCode, additionalParameters: nil)

		return Promise<OIDAuthState> { fulfill, reject in
			GoogleDriveCloudAuthentication.currentAuthorizationFlow = OIDAuthState.authState(byPresenting: request, presenting: presentingViewController, callback: { authState, error in
				guard let authState = authState, error == nil else {
					self.authorization = nil
					if let error = error as NSError? {
						if error.domain == OIDGeneralErrorDomain, error.code == OIDErrorCode.userCanceledAuthorizationFlow.rawValue || error.code == OIDErrorCode.programCanceledAuthorizationFlow.rawValue {
							return reject(CloudAuthenticationError.userCanceled)
						}
						return reject(error)
					}

					return reject(GoogleDriveError.unexpectedError) // MARK: This should never occur
				}
				fulfill(authState)
            })
		}
	}
}
