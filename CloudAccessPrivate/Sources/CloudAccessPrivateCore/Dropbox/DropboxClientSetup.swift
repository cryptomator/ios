//
//  DropboxClientSetup.swift
//
//
//  Created by Philipp Schmid on 06.10.20.
//

import Foundation
import ObjectiveDropboxOfficial
public class DropboxClientSetup {
	private static var firstTimeInit = true
	public static func oneTimeSetup() {
		if firstTimeInit {
			firstTimeInit = false
			let config = DBTransportDefaultConfig(appKey: CloudAccessSecrets.dropboxAppKey, appSecret: nil, userAgent: nil, asMemberId: nil, delegateQueue: nil, forceForegroundSession: false, sharedContainerIdentifier: CryptomatorConstants.appGroupName)
			DBClientsManager.setup(withTransport: config)
		}
	}
}
