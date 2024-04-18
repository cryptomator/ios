//
//  BoxTokenStore.swift
//
//
//  Created by Majid Achhoud on 10.04.24.
//

import BoxSDK
import Foundation

public enum BoxTokenStoreError: Error {
	case keychainNoValue
	case cantSaveToKeychain
}

public struct BoxTokenStore: TokenStore {
	public init() {}

	public func read(completion: @escaping (Result<TokenInfo, any Error>) -> Void) {
		guard let tokenInfo = CryptomatorKeychain.box.getBoxTokenInfo() else {
			completion(.failure(BoxTokenStoreError.keychainNoValue))
			return
		}
		completion(.success(tokenInfo))
	}

	public func write(tokenInfo: TokenInfo, completion: @escaping (Result<Void, any Error>) -> Void) {
		guard let newTokenInfo = try? CryptomatorKeychain.box.saveBoxTokenInfo(tokenInfo) else {
			completion(.failure(BoxTokenStoreError.cantSaveToKeychain))
			return
		}
		completion(.success(newTokenInfo))
	}

	public func clear(completion: @escaping (Result<Void, any Error>) -> Void) {
		do {
			try CryptomatorKeychain.box.deleteTokenInfo()
			completion(.success(()))
		} catch {
			completion(.failure(error))
		}
	}
}

extension CryptomatorKeychain {
	func getBoxTokenInfo() -> TokenInfo? {
		guard let data = getAsData("foo") else {
			return nil
		}
		do {
			let jsonDecoder = JSONDecoder()
			return try jsonDecoder.decode(TokenInfo.self, from: data)
		} catch {
			return nil
		}
	}

	func saveBoxTokenInfo(_ tokenInfo: TokenInfo) throws {
		let jsonEncoder = JSONEncoder()
		let encodedUser = try jsonEncoder.encode(tokenInfo)
		try set("foo", value: encodedUser)
	}

	func deleteTokenInfo() throws {
		try delete("foo")
	}
}
