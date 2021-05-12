//
//  WebDAVAuthenticator+Keychain.swift
//	CryptomatorCommonCore
//
//  Created by Philipp Schmid on 21.10.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation

public extension WebDAVAuthenticator {
	static func getCredentialFromKeychain(with accountUID: String) -> WebDAVCredential? {
		return CryptomatorKeychain.webDAV.get(accountUID)
	}

	static func saveCredentialToKeychain(_ credential: WebDAVCredential, with accountUID: String) throws {
		let jsonEnccoder = JSONEncoder()
		let encodedCredential = try jsonEnccoder.encode(credential)
		try CryptomatorKeychain.webDAV.set(accountUID, value: encodedCredential)
	}

	static func removeCredentialFromKeychain(with accountUID: String) throws {
		try CryptomatorKeychain.webDAV.delete(accountUID)
	}
}

private extension CryptomatorKeychain {
	func get(_ key: String) -> WebDAVCredential? {
		guard let data = getAsData(key) else {
			return nil
		}
		do {
			let jsonDecoder = JSONDecoder()
			return try jsonDecoder.decode(WebDAVCredential.self, from: data)
		} catch {
			return nil
		}
	}
}
