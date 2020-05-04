//
//  MockGoogleDriveCloudAuthentication.swift
//  CryptomatorIntegrationTests
//
//  Created by Philipp Schmid on 29.04.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Foundation
@testable import CloudAccessPrivate
import Promises
import GTMAppAuth
@testable import AppAuth
class MockGoogleDriveCloudAuthentication: GoogleDriveCloudAuthentication {
    
    
    func authenticate(withRefreshToken refreshToken: NSString) -> Promise<Void> {
        
        let authorizationEndpoint = URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        let tokenEndPoint = URL(string: "https://oauth2.googleapis.com/token")!
        let configuration = OIDServiceConfiguration(authorizationEndpoint: authorizationEndpoint, tokenEndpoint: tokenEndPoint)
        let authRequest = OIDAuthorizationRequest(configuration: configuration, clientId: self.clientId , clientSecret: nil, scope: nil, redirectURL: self.redirectURL, responseType: "code", state: nil, nonce: nil, codeVerifier: nil, codeChallenge: nil, codeChallengeMethod: nil, additionalParameters: nil)
        let authResponse = OIDAuthorizationResponse(request: authRequest, parameters: [String : NSCopying & NSObjectProtocol]())
    
        let tokenRequest = OIDTokenRequest(configuration: configuration, grantType: "authorization_code", authorizationCode: nil, redirectURL: self.redirectURL, clientID: self.clientId, clientSecret: nil, scopes: nil, refreshToken: nil, codeVerifier: nil, additionalParameters: nil)
        let tokenParameters = ["refresh_token" :  refreshToken]
        let tokenResponse = OIDTokenResponse(request: tokenRequest, parameters: tokenParameters)
        let authState = OIDAuthState(authorizationResponse: authResponse, tokenResponse: tokenResponse)
        let authorization = GTMAppAuthFetcherAuthorization(authState: authState)
        self.authorization = authorization
        return Promise(())
        
        
    }
}
