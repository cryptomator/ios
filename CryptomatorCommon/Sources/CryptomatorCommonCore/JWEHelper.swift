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
			throw VaultManagerError.invalidDecrypter
		}
		let payload = try jwe.decrypt(using: decrypter)
		let payloadMasterkey = try JSONDecoder().decode(PayloadMasterkey.self, from: payload.data())

		guard let masterkeyData = Data(base64Encoded: payloadMasterkey.key) else {
			throw VaultManagerError.invalidPayloadMasterkey
		}
		return Masterkey.createFromRaw(rawKey: [UInt8](masterkeyData))
	}
}
