//
//  DropboxCredential.swift
//  CloudAccessPrivate-Core
//
//  Created by Philipp Schmid on 23.09.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Foundation
import ObjectiveDropboxOfficial
import Promises
public enum DropboxCredentialErrors: Error {
	case noUsername
}

public class DropboxCredential {
	public internal(set) var authorizedClient: DBUserClient?
	public let tokenUid: String
	public var isAuthorized: Bool {
		authorizedClient?.isAuthorized() ?? false
	}

	public init(tokenUid: String) {
		self.tokenUid = tokenUid
		DropboxClientSetup.oneTimeSetup()
		setAuthorizedClient()
	}

	public func setAuthorizedClient() {
		authorizedClient = DBClientsManager.authorizedClients()[tokenUid]
	}

	public func deauthenticate() {
		authorizedClient = nil
		DBClientsManager.unlinkAndResetClient(tokenUid)
	}

	public func getUsername() -> Promise<String> {
		return Promise<String>(on: .global()) { fulfill, reject in
			self.authorizedClient?.usersRoutes.getCurrentAccount().setResponseBlock { result, _, networkError in
				if let error = networkError?.nsError {
					reject(error)
					return
				}
				guard let result = result else {
					reject(DropboxCredentialErrors.noUsername)
					return
				}
				fulfill(result.name.displayName)
			}
		}
	}
}
