//
//  BoxTokenStore.swift
//
//
//  Created by Majid Achhoud on 10.04.24.
//

import BoxSdkGen
import Foundation

public enum BoxTokenStoreError: Error {
	case keychainNoValue
	case cantSaveToKeychain
}

public struct BoxTokenStore: TokenStorage {
	public init() {}

	public func store(token: AccessToken) async throws {
		do {
			try CryptomatorKeychain.box.saveBoxTokenInfo(token)
		} catch {
			throw BoxTokenStoreError.cantSaveToKeychain
		}
	}

	public func get() async throws -> AccessToken? {
		guard let tokenInfo = CryptomatorKeychain.box.getBoxTokenInfo() else {
			throw BoxTokenStoreError.keychainNoValue
		}
		return tokenInfo
	}

	public func clear() async throws {
		do {
			try CryptomatorKeychain.box.deleteTokenInfo()
		} catch {
			throw error
		}
	}
}

extension CryptomatorKeychain {
	func getBoxTokenInfo() -> AccessToken? {
		guard let data = getAsData("foo") else {
			return nil
		}
		do {
			let jsonDecoder = JSONDecoder()
			return try jsonDecoder.decode(AccessToken.self, from: data)
		} catch {
			return nil
		}
	}

	func saveBoxTokenInfo(_ tokenInfo: AccessToken) throws {
		let jsonEncoder = JSONEncoder()
		let encodedUser = try jsonEncoder.encode(tokenInfo)
		try set("foo", value: encodedUser)
		let encodedToken = try jsonEncoder.encode(tokenInfo)
		try set("foo", value: encodedToken)
	}

	func deleteTokenInfo() throws {
		try delete("foo")
	}
}
