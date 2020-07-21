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

public enum DropboxAuthenticationError: Error {
	case authenticationFailed
	case noUsername
}

public class DropboxCloudAuthentication {
	public static var pendingAuthentication: Promise<Void>?
	public var authorizedClient: DBUserClient?
	private static var firstTimeInit = true
	public var isAuthenticated: Bool {
		return DBClientsManager.authorizedClient()?.isAuthorized() ?? false
	}

	/**
	 Add DBClientsManager.setup(..) to the AppDelegate
	 */
	public init() {
		// MARK: Add sharedContainerIdentifier

		if DropboxCloudAuthentication.firstTimeInit {
			DropboxCloudAuthentication.firstTimeInit = false
			let config = DBTransportDefaultConfig(appKey: CloudAccessSecrets.dropboxAppKey, appSecret: nil, userAgent: nil, asMemberId: nil, delegateQueue: nil, forceForegroundSession: false, sharedContainerIdentifier: nil)
			DBClientsManager.setup(withTransport: config)
		}
	}

	public func authenticate(from viewController: UIViewController) -> Promise<Void> {
		if isAuthenticated {
			authorizedClient = DBClientsManager.authorizedClient()
			return Promise(())
		}

		DropboxCloudAuthentication.pendingAuthentication?.reject(DropboxAuthenticationError.authenticationFailed)
		let pendingAuthentication = Promise<Void>.pending()
		DropboxCloudAuthentication.pendingAuthentication = pendingAuthentication
		DBClientsManager.authorize(fromController: .shared, controller: viewController) { url in
			UIApplication.shared.open(url, options: [:], completionHandler: nil)
		}
		return pendingAuthentication.then {
			self.authorizedClient = DBClientsManager.authorizedClient()
		}
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
					reject(DropboxAuthenticationError.noUsername)
					return
				}
				fulfill(result.name.displayName)
			}
		}
	}

	public func deauthenticate() -> Promise<Void> {
		DBClientsManager.unlinkAndResetClients()
		authorizedClient = nil
		return Promise(())
	}
}
