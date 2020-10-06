//
//  MockGoogleDriveAuthenticator.swift
//  CryptomatorIntegrationTests
//
//  Created by Philipp Schmid on 02.10.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import AppAuth
import Foundation
import GoogleAPIClientForREST_Drive
import GTMAppAuth
@testable import CloudAccessPrivateCore

class MockGoogleDriveAuthenticator {
	static func generateAuthorizedCredential(withRefreshToken refreshToken: String, tokenUid: String) -> GoogleDriveCredential {
		let authorizationEndpoint = URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!
		let tokenEndPoint = URL(string: "https://oauth2.googleapis.com/token")!
		let configuration = OIDServiceConfiguration(authorizationEndpoint: authorizationEndpoint, tokenEndpoint: tokenEndPoint)
		let authRequest = OIDAuthorizationRequest(configuration: configuration, clientId: CloudAccessSecrets.googleDriveClientId, clientSecret: nil, scope: nil, redirectURL: CloudAccessSecrets.googleDriveRedirectURL, responseType: "code", state: nil, nonce: nil, codeVerifier: nil, codeChallenge: nil, codeChallengeMethod: nil, additionalParameters: nil)
		let authResponse = OIDAuthorizationResponse(request: authRequest, parameters: [String: NSCopying & NSObjectProtocol]())

		let tokenRequest = OIDTokenRequest(configuration: configuration, grantType: "authorization_code", authorizationCode: nil, redirectURL: CloudAccessSecrets.googleDriveRedirectURL, clientID: CloudAccessSecrets.googleDriveClientId, clientSecret: nil, scopes: nil, refreshToken: nil, codeVerifier: nil, additionalParameters: nil)
		let tokenParameters = ["refresh_token": refreshToken as NSString]
		let tokenResponse = OIDTokenResponse(request: tokenRequest, parameters: tokenParameters)
		let authState = OIDAuthState(authorizationResponse: authResponse, tokenResponse: tokenResponse)
		let credential = GoogleDriveCredential(with: tokenUid)
		credential.save(authState: authState)
		return credential
	}
}
