#!/bin/sh
cat > ./CryptomatorIntegrationTests/IntegrationTestSecrets.swift << EOM
//
//  IntegrationTestSecrets.swift
//  CryptomatorIntegrationTests
//
//  Created by Tobias Hagemann on 20.05.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import Foundation

struct IntegrationTestSecrets {
	static let googleDriveRefreshToken = "${GOOGLE_DRIVE_REFRESH_TOKEN}"
	static let dropboxAccessToken = "${DROPBOX_ACCESS_TOKEN}"
	static let webDAVCredential = WebDAVCredential(baseURL: URL(string: "${WEBDAV_BASE_URL}")!, username: "${WEBDAV_USERNAME}", password: "${WEBDAV_PASSWORD}", allowedCertificate: nil)
}
EOM
