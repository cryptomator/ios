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
import AppAuth
class MockGoogleDriveCloudAuthentication: GoogleDriveCloudAuthentication {
    
    //MARK: Implement here the auth with a refresh token
    func authenticate(with refreshToken: String) -> Promise<Void> {
        fatalError("not implemented")
//        OIDTokenRequest(configuration: <#T##OIDServiceConfiguration#>, grantType: <#T##String#>, authorizationCode: <#T##String?#>, redirectURL: <#T##URL?#>, clientID: <#T##String#>, clientSecret: <#T##String?#>, scope: <#T##String?#>, refreshToken: <#T##String?#>, codeVerifier: <#T##String?#>, additionalParameters: <#T##[String : String]?#>)
//        OIDAuthState(authorizationResponse: <#T##OIDAuthorizationResponse#>, tokenResponse: <#T##OIDTokenResponse?#>)
    }
}
