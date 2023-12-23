//
//  JWEHelper.swift
//
//
//  Created by Philipp Schmid on 22.07.22.
//

import CryptoKit
import CryptomatorCryptoLib
import Foundation
import JOSESwift

public enum JWEHelper {
	public static func decrypt(jwe: JWE, with privateKey: P384.KeyAgreement.PrivateKey) throws -> Masterkey {
		// see https://developer.apple.com/forums/thread/680554
		let x = privateKey.x963Representation[1 ..< 49]
		let y = privateKey.x963Representation[49 ..< 97]
		let k = privateKey.x963Representation[97 ..< 145]
		let decryptionKey = try ECPrivateKey(crv: "P-384", x: x.base64UrlEncodedString(), y: y.base64UrlEncodedString(), privateKey: k.base64UrlEncodedString())

		guard let decrypter = Decrypter(keyManagementAlgorithm: .ECDH_ES, contentEncryptionAlgorithm: .A256GCM, decryptionKey: decryptionKey) else {
			// TODO: Change Error
			throw VaultManagerError.invalidDecrypter
		}
		let payload = try jwe.decrypt(using: decrypter)
		let payloadMasterkey = try JSONDecoder().decode(PayloadMasterkey.self, from: payload.data())

		guard let masterkeyData = Data(base64Encoded: payloadMasterkey.key) else {
			throw VaultManagerError.invalidPayloadMasterkey
		}
		return Masterkey.createFromRaw(rawKey: [UInt8](masterkeyData))
	}

	public static func decryptUserKey(jwe: JWE, setupCode: String) throws -> String {
		guard let decrypter = Decrypter(keyManagementAlgorithm: .PBES2_HS512_A256KW, contentEncryptionAlgorithm: .A256GCM, decryptionKey: setupCode) else {
			// TODO: Change Error
			throw VaultManagerError.invalidDecrypter
		}
		let payload = try jwe.decrypt(using: decrypter)
		let payloadData = payload.data()
		guard let jsonObject = try JSONSerialization.jsonObject(with: payloadData, options: []) as? [String: Any],
		      let key = jsonObject["key"] as? String else {
			// TODO: Change Error
			throw VaultManagerError.invalidPayloadMasterkey
		}
		return key
	}

	public static func encryptUserKey(userKey: String, deviceKey: P384.KeyAgreement.PublicKey) throws -> JWE {
		let header = JWEHeader(keyManagementAlgorithm: .ECDH_ES, contentEncryptionAlgorithm: .A256GCM)
		let x = deviceKey.x963Representation[1 ..< 49]
		let y = deviceKey.x963Representation[49 ..< 97]
		let encryptionKey = ECPublicKey(crv: .P384,
		                                x: x.base64EncodedString(),
		                                y: y.base64EncodedString())
		guard let encrypter = Encrypter(keyManagementAlgorithm: .ECDH_ES,
		                                contentEncryptionAlgorithm: .A256GCM,
		                                encryptionKey: encryptionKey) else {
			// TODO: Change Error
			throw VaultManagerError.invalidDecrypter
		}
		guard let userKey = userKey.data(using: .utf8) else {
			// TODO: Change Error
			throw VaultManagerError.invalidDecrypter
		}
		let payload = Payload(userKey)
		return try JWE(header: header, payload: payload, encrypter: encrypter)
	}
}
