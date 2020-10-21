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
@testable import CloudAccessPrivateCore
class MockDropboxCredential: DropboxCredential {
	init() {
		super.init(tokenUid: "IntegrationTest")
	}

	override func setAuthorizedClient() {
		let config = DBTransportDefaultConfig(appKey: CloudAccessSecrets.dropboxAppKey, appSecret: nil, userAgent: nil, asMemberId: nil, delegateQueue: nil, forceForegroundSession: false, sharedContainerIdentifier: CryptomatorConstants.appGroupName)
		authorizedClient = DBUserClient(accessToken: IntegrationTestSecrets.dropboxAccessToken, transport: config)
	}

	override func deauthenticate() {
		authorizedClient = nil
	}
}
