//
//  WebDAVAuthenticator+Keychain.swift
//	CloudAccessPrivateCore
//
//  Created by Philipp Schmid on 21.10.20.
//

import CryptomatorCloudAccess
import Foundation
extension WebDAVAuthenticator {
	public static func getCredentialFromKeychain(with accountUID: String) -> WebDAVCredential? {
		return WebDavKeychain.get(accountUID)
	}

	public static func saveCredentialToKeychain(_ credential: WebDAVCredential, with accountUID: String) -> Bool {
		let jsonEnccoder = JSONEncoder()
		guard let encodedCredential = try? jsonEnccoder.encode(credential) else {
			return false
		}
		return WebDavKeychain.set(accountUID, value: encodedCredential)
	}

	public static func removeCredentialFromKeychain(with accountUID: String) -> Bool {
		return WebDavKeychain.delete(accountUID)
	}
}

class WebDavKeychain: CryptomatorKeychain {
	static let service = "webDAV.auth"

	class func get(_ key: String) -> WebDAVCredential? {
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
