//
//  CryptomatorKeychain+S3.swift
//
//
//  Created by Philipp Schmid on 29.06.22.
//

import CryptomatorCloudAccessCore
import Foundation

extension CryptomatorKeychainType {
	func getS3Credential(_ identifier: String) -> S3Credential? {
		guard let data = getAsData(identifier) else {
			return nil
		}
		do {
			let jsonDecoder = JSONDecoder()
			return try jsonDecoder.decode(S3Credential.self, from: data)
		} catch {
			return nil
		}
	}

	func saveS3Credential(_ credential: S3Credential) throws {
		let identifier = String(credential.identifier)
		let jsonEncoder = JSONEncoder()
		let encodedCredential = try jsonEncoder.encode(credential)
		try set(identifier, value: encodedCredential)
	}
}
