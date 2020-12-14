//
//  DropboxCloudAuthenticator.swift
//  CloudAccessPrivate-Auth
//
//  Created by Philipp Schmid on 29.05.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//
import CloudAccessPrivateCore
import CryptomatorCloudAccess
import Foundation
import ObjectiveDropboxOfficial
import Promises

public enum DropboxAuthenticationError: Error {
	case authenticationFailed
	case noPendingAuthentication
	case userCanceled
}

public class DropboxCloudAuthenticator {
	public static var pendingAuthentication: Promise<DropboxCredential>?

	public init() {
		DropboxClientSetup.oneTimeSetup()
	}

	@available(iOSApplicationExtension, unavailable)
	public func authenticate(from viewController: UIViewController) -> Promise<DropboxCredential> {
		// TODO: Check for existing authentication?

		DropboxCloudAuthenticator.pendingAuthentication?.reject(DropboxAuthenticationError.authenticationFailed)
		let pendingAuthentication = Promise<DropboxCredential>.pending()
		DropboxCloudAuthenticator.pendingAuthentication = pendingAuthentication
		DBClientsManager.authorize(fromController: .shared, controller: viewController) { url in
			UIApplication.shared.open(url, options: [:], completionHandler: nil)
		}
		return pendingAuthentication
	}

	public func processAuthentication(with tokenUid: String) throws {
		guard let pendingAuthentication = DropboxCloudAuthenticator.pendingAuthentication else {
			throw DropboxAuthenticationError.noPendingAuthentication
		}
		pendingAuthentication.fulfill(DropboxCredential(tokenUid: tokenUid))
	}

	public func deauthenticate() -> Promise<Void> {
		DBClientsManager.unlinkAndResetClients()
		// TODO: set all existing DropboxCredential.authorizedClient to nil
		return Promise(())
	}
}
