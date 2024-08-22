//
//  BoxTokenStorage.swift
//  CryptomatorCommonCore
//
//  Created by Majid Achhoud on 10.04.24.
//  Copyright © 2024 Skymatic GmbH. All rights reserved.
//

import BoxSdkGen
import CocoaLumberjackSwift
import Foundation

public class BoxTokenStorage: TokenStorage {
	public var userID: String? {
		didSet {
			if let token = pendingToken, let userID = userID {
				do {
					try CryptomatorKeychain.box.saveBoxAccessToken(token, for: userID)
					pendingToken = nil
				} catch {
					DDLogError("Saving Box access token to keychain failed with error: \(error)")
				}
			}
		}
	}

	private var pendingToken: AccessToken?

	public init(userID: String? = nil) {
		self.userID = userID
	}

	public func store(token: AccessToken) async throws {
		guard let userID = userID else {
			pendingToken = token
			return
		}
		try CryptomatorKeychain.box.saveBoxAccessToken(token, for: userID)
	}

	public func get() async throws -> AccessToken? {
		if let pendingToken = pendingToken {
			return pendingToken
		}
		guard let userID = userID else {
			return nil
		}
		return CryptomatorKeychain.box.getBoxAccessToken(userID)
	}

	public func clear() async throws {
		guard let userID = userID else {
			return
		}
		try CryptomatorKeychain.box.deleteBoxAccessToken(userID)
	}
}

extension CryptomatorKeychain {
	func getBoxAccessToken(_ userID: String) -> AccessToken? {
		guard let data = getAsData(userID) else {
			return nil
		}
		do {
			let jsonDecoder = JSONDecoder()
			return try jsonDecoder.decode(AccessToken.self, from: data)
		} catch {
			return nil
		}
	}

	func saveBoxAccessToken(_ accessToken: AccessToken, for userID: String) throws {
		let jsonEncoder = JSONEncoder()
		let encodedToken = try jsonEncoder.encode(accessToken)
		try set(userID, value: encodedToken)
	}

	func deleteBoxAccessToken(_ userID: String) throws {
		try delete(userID)
	}
}
