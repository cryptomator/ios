//
//  GoogleDriveCloudAuthenticator.swift
//  CloudAccessPrivate-Auth
//
//  Created by Philipp Schmid on 24.04.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import AppAuth
import CloudAccessPrivateCore
import CryptomatorCloudAccess
import Foundation
import GoogleAPIClientForREST_Drive
import Promises
public enum GoogleDriveAuthenticationError: Error {
	case userCanceled
}

public class GoogleDriveCloudAuthenticator {
	private static let scopes = [kGTLRAuthScopeDrive]
	public static var currentAuthorizationFlow: OIDExternalUserAgentSession?

	public static func authenticate(credential: GoogleDriveCredential, from viewController: UIViewController) -> Promise<Void> {
		if credential.isAuthorized {
			return Promise(())
		}
		return createAuthorizationServiceForGoogle().then { configuration in
			self.getAuthState(for: configuration, with: viewController, credential: credential)
		}.then { authState in
			credential.save(authState: authState)
			return Promise(())
		}
	}

	private static func createAuthorizationServiceForGoogle() -> Promise<OIDServiceConfiguration> {
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

	private static func getAuthState(for configuration: OIDServiceConfiguration, with presentingViewController: UIViewController, credential: GoogleDriveCredential) -> Promise<OIDAuthState> {
		let request = OIDAuthorizationRequest(configuration: configuration, clientId: CloudAccessSecrets.googleDriveClientId, scopes: scopes, redirectURL: CloudAccessSecrets.googleDriveRedirectURL!, responseType: OIDResponseTypeCode, additionalParameters: nil)

		return Promise<OIDAuthState> { fulfill, reject in
			GoogleDriveCloudAuthenticator.currentAuthorizationFlow = OIDAuthState.authState(byPresenting: request, presenting: presentingViewController, callback: { authState, error in
				guard let authState = authState, error == nil else {
					credential.deauthenticate()
					if let error = error as NSError? {
						if error.domain == OIDGeneralErrorDomain, error.code == OIDErrorCode.userCanceledAuthorizationFlow.rawValue || error.code == OIDErrorCode.programCanceledAuthorizationFlow.rawValue {
							return reject(GoogleDriveAuthenticationError.userCanceled)
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
