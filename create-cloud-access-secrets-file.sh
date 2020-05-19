#!/bin/sh
cat > ./CloudAccessPrivate/CloudAccessSecrets.swift << EOM
//
//  CloudAccessSecrets.swift
//  CloudAccessPrivate
//
//  Created by Tobias Hagemann on 19.05.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Foundation

struct CloudAccessSecrets {
	static let googleDriveClientId = "${GOOGLE_DRIVE_CLIENT_ID}"
	static let googleDriveRedirectURL = URL(string: "${GOOGLE_DRIVE_REDIRECT_URL}")
}
EOM
