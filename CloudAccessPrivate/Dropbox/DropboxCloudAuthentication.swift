//
//  DropboxCloudAuthentication.swift
//  CloudAccessPrivate
//
//  Created by Philipp Schmid on 29.05.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import Foundation
import Promises
class DropboxCloudAuthentication: CloudAuthentication {
	func authenticate(from _: UIViewController) -> Promise<Void> {
		return Promise(CloudProviderError.noInternetConnection)
	}

	func isAuthenticated() -> Promise<Bool> {
		return Promise(CloudProviderError.noInternetConnection)
	}

	func getUsername() -> Promise<String> {
		return Promise(CloudProviderError.noInternetConnection)
	}

	func deauthenticate() -> Promise<Void> {
		return Promise(CloudProviderError.noInternetConnection)
	}
}
