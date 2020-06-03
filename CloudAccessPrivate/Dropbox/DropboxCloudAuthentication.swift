//
//  DropboxCloudAuthentication.swift
//  CloudAccessPrivate
//
//  Created by Philipp Schmid on 29.05.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import Foundation
import ObjectiveDropboxOfficial
import Promises
class DropboxCloudAuthentication: CloudAuthentication {
	init() {
		// MARK: Add sharedContainerIdentifier

		let config = DBTransportDefaultConfig(appKey: CloudAccessSecrets.dropboxAppKey, appSecret: nil, userAgent: nil, asMemberId: nil, delegateQueue: nil, forceForegroundSession: false, sharedContainerIdentifier: nil)
		DBClientsManager.setup(withTransport: config)
	}

	func authenticate(from viewController: UIViewController) -> Promise<Void> {
		return isAuthenticated().then { isAuthenticated in
			if isAuthenticated {
				return Promise(())
			}
			DBClientsManager.authorize(fromController: .shared, controller: viewController) { url in
				UIApplication.shared.open(url, options: [:], completionHandler: nil)
			}
			return Promise(())
		}
	}

	func isAuthenticated() -> Promise<Bool> {
		return Promise(DBClientsManager.authorizedClient()?.isAuthorized() ?? false)
	}

	func getUsername() -> Promise<String> {
		let client = DBClientsManager.authorizedClient()
		return Promise<String>(on: .global()) { fulfill, reject in
			client?.usersRoutes.getCurrentAccount().setResponseBlock { result, _, networkError in
				if let error = networkError?.nsError {
					reject(error)
					return
				}
				guard let result = result else {
					reject(DropboxError.unexpectedError)
					return
				}
				fulfill(result.name.displayName)
			}
		}
	}

	func deauthenticate() -> Promise<Void> {
		DBClientsManager.unlinkAndResetClients()
		return Promise(())
	}
}
