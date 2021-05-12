if [ -f ./.cloud-access-secrets.sh ]; then
  source ./.cloud-access-secrets.sh
else
  echo "warning: .cloud-access-secrets.sh could not be found, please see README for instructions"
fi
cat > ./CryptomatorCommon/Sources/CryptomatorCommonCore/CloudAccessSecrets.swift << EOM
//
//  CloudAccessSecrets.swift
//  CryptomatorCommonCore
//
//  Created by Tobias Hagemann on 19.05.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Foundation

public enum CloudAccessSecrets {
	public static let googleDriveClientId = "${GOOGLE_DRIVE_CLIENT_ID}"
	public static let googleDriveRedirectURL = URL(string: "${GOOGLE_DRIVE_REDIRECT_URL}")
	public static let dropboxAppKey = "${DROPBOX_APP_KEY}"
	public static let dropboxURLScheme = "db-${DROPBOX_APP_KEY}"
	public static let oneDriveClientId = "${ONEDRIVE_CLIENT_ID}"
	public static let oneDriveRedirectUri = "${ONEDRIVE_REDIRECT_URI_SCHEME}://auth"
}
EOM
