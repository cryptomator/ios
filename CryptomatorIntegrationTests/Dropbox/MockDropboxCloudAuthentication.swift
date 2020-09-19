//
//  MockDropboxCloudAuthentication.swift
//  CryptomatorIntegrationTests
//
//  Created by Philipp Schmid on 04.06.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Foundation
import ObjectiveDropboxOfficial
import Promises
@testable import CloudAccessPrivate
class MockDropboxCloudAuthentication: DropboxCloudAuthentication {
	func authenticate() {
		if isAuthenticated {
			authorizedClient = DBClientsManager.authorizedClient()
		} else {
			// MARK: Check if we can get the backgroundSession Working in XCTest

			let config = DBTransportDefaultConfig(appKey: CloudAccessSecrets.dropboxAppKey, appSecret: nil, userAgent: nil, asMemberId: nil, delegateQueue: nil, forceForegroundSession: false, sharedContainerIdentifier: "group.com.skymatic.Cryptomator")
			authorizedClient = DBUserClient(accessToken: IntegrationTestSecrets.dropboxAccessToken, transport: config)
		}
	}
}
