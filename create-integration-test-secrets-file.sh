#!/bin/sh
cat > ./CryptomatorIntegrationTests/IntegrationTestSecrets.swift << EOM
//
//  IntegrationTestSecrets.swift
//  CloudAccessPrivate
//
//  Created by Tobias Hagemann on 20.05.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Foundation

struct IntegrationTestSecrets {
	static let googleDriveRefreshToken = "${GOOGLE_DRIVE_REFRESH_TOKEN}"
}
EOM
