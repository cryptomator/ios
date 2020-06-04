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
public class DropboxCloudAuthentication: CloudAuthentication {
	public static var pendingAuthentication: Promise<Void>?
	public init() {
		// MARK: Add sharedContainerIdentifier

		let config = DBTransportDefaultConfig(appKey: CloudAccessSecrets.dropboxAppKey, appSecret: nil, userAgent: nil, asMemberId: nil, delegateQueue: nil, forceForegroundSession: false, sharedContainerIdentifier: nil)
		DBClientsManager.setup(withTransport: config)
	}

	public func authenticate(from viewController: UIViewController) -> Promise<Void> {
		return isAuthenticated().then { isAuthenticated in
			if isAuthenticated {
				return Promise(())
			}

			DropboxCloudAuthentication.pendingAuthentication?.reject(CloudAuthenticationError.authenticationFailed)
			let pendingAuthentication = Promise<Void>.pending()
			DropboxCloudAuthentication.pendingAuthentication = pendingAuthentication
			DBClientsManager.authorize(fromController: .shared, controller: viewController) { url in
				UIApplication.shared.open(url, options: [:], completionHandler: nil)
			}
			return pendingAuthentication
		}
	}

	public func isAuthenticated() -> Promise<Bool> {
		return Promise(DBClientsManager.authorizedClient()?.isAuthorized() ?? false)
	}

	public func getUsername() -> Promise<String> {
		let client = DBClientsManager.authorizedClient()
		return Promise<String>(on: .global()) { fulfill, reject in
			client?.usersRoutes.getCurrentAccount().setResponseBlock { result, _, networkError in
				if let error = networkError?.nsError {
					reject(error)
					return
				}
				guard let result = result else {
					reject(CloudAuthenticationError.noUsername)
					return
				}
				fulfill(result.name.displayName)
			}
		}
	}

	public func deauthenticate() -> Promise<Void> {
		DBClientsManager.unlinkAndResetClients()
		return Promise(())
	}
}
