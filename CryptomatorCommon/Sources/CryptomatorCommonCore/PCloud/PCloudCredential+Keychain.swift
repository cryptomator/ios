//
//  PCloudCredential+Keychain.swift
//  CryptomatorCommonCore
//
//  Created by Tobias Hagemann on 28.02.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation
import PCloudSDKSwift

public extension PCloudCredential {
	convenience init(userID: String) throws {
		guard let user = CryptomatorKeychain.pCloud.getPCloudUser(userID) else {
			throw CloudProviderAccountError.accountNotFoundError
		}
		self.init(user: user)
	}

	func saveToKeychain() throws {
		try CryptomatorKeychain.pCloud.savePCloudUser(user)
	}

	func deauthenticate() throws {
		try CryptomatorKeychain.pCloud.delete(userID)
	}
}

extension CryptomatorKeychain {
	func getPCloudUser(_ userID: String) -> OAuth.User? {
		guard let data = getAsData(userID) else {
			return nil
		}
		do {
			let jsonDecoder = JSONDecoder()
			return try jsonDecoder.decode(OAuth.User.self, from: data)
		} catch {
			return nil
		}
	}

	func savePCloudUser(_ user: OAuth.User) throws {
		let userID = String(user.id)
		let jsonEncoder = JSONEncoder()
		let encodedUser = try jsonEncoder.encode(user)
		try set(userID, value: encodedUser)
	}
}
