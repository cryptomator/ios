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
import SwiftECC

public enum JWEHelperError: Error {
	case invalidDecrypter
	case invalidMasterkeyPayload
}

public enum JWEHelper {
	public static func decryptVaultKey(jwe: JWE, with privateKey: P384.KeyAgreement.PrivateKey) throws -> Masterkey {
		// see https://developer.apple.com/forums/thread/680554
		let x = privateKey.x963Representation[1 ..< 49]
		let y = privateKey.x963Representation[49 ..< 97]
		let k = privateKey.x963Representation[97 ..< 145]
		let decryptionKey = try ECPrivateKey(crv: "P-384", x: x.base64UrlEncodedString(), y: y.base64UrlEncodedString(), privateKey: k.base64UrlEncodedString())

		guard let decrypter = Decrypter(keyManagementAlgorithm: .ECDH_ES, contentEncryptionAlgorithm: .A256GCM, decryptionKey: decryptionKey) else {
			throw JWEHelperError.invalidDecrypter
		}
		let payload = try jwe.decrypt(using: decrypter)
		let payloadMasterkey = try JSONDecoder().decode(PayloadMasterkey.self, from: payload.data())

		guard let masterkeyData = Data(base64Encoded: payloadMasterkey.key) else {
			throw JWEHelperError.invalidMasterkeyPayload
		}
		return Masterkey.createFromRaw(rawKey: [UInt8](masterkeyData))
	}

	public static func decryptUserKey(jwe: JWE, privateKey: P384.KeyAgreement.PrivateKey) throws -> P384.KeyAgreement.PrivateKey {
		let x = privateKey.x963Representation[1 ..< 49]
		let y = privateKey.x963Representation[49 ..< 97]
		let k = privateKey.x963Representation[97 ..< 145]
		let decryptionKey = try ECPrivateKey(crv: "P-384",
		                                     x: x.base64UrlEncodedString(),
		                                     y: y.base64UrlEncodedString(),
		                                     privateKey: k.base64UrlEncodedString())
		guard let decrypter = Decrypter(keyManagementAlgorithm: .ECDH_ES,
		                                contentEncryptionAlgorithm: .A256GCM,
		                                decryptionKey: decryptionKey) else {
			throw JWEHelperError.invalidDecrypter
		}
		let payload = try jwe.decrypt(using: decrypter)
		return try decodeUserKey(payload: payload)
	}

	public static func decryptUserKey(jwe: JWE, setupCode: String) throws -> P384.KeyAgreement.PrivateKey {
		guard let decrypter = Decrypter(keyManagementAlgorithm: .PBES2_HS512_A256KW,
		                                contentEncryptionAlgorithm: .A256GCM,
		                                decryptionKey: setupCode) else {
			throw JWEHelperError.invalidDecrypter
		}
		let payload = try jwe.decrypt(using: decrypter)
		return try decodeUserKey(payload: payload)
	}

	public static func encryptUserKey(userKey: P384.KeyAgreement.PrivateKey, deviceKey: P384.KeyAgreement.PublicKey) throws -> JWE {
		let header = JWEHeader(keyManagementAlgorithm: .ECDH_ES, contentEncryptionAlgorithm: .A256GCM)
		let x = deviceKey.x963Representation[1 ..< 49]
		let y = deviceKey.x963Representation[49 ..< 97]
		let encryptionKey = ECPublicKey(crv: .P384,
		                                x: x.base64EncodedString(),
		                                y: y.base64EncodedString())
		guard let encrypter = Encrypter(keyManagementAlgorithm: .ECDH_ES,
		                                contentEncryptionAlgorithm: .A256GCM,
		                                encryptionKey: encryptionKey) else {
			throw JWEHelperError.invalidDecrypter
		}
		let payloadKey = try PayloadMasterkey(key: userKey.derPkcs8().base64EncodedString())
		let payload = try Payload(JSONEncoder().encode(payloadKey))
		return try JWE(header: header, payload: payload, encrypter: encrypter)
	}

	private static func decodeUserKey(payload: Payload) throws -> P384.KeyAgreement.PrivateKey {
		let decodedPayload = try JSONDecoder().decode(PayloadMasterkey.self, from: payload.data())

		guard let privateKeyData = Data(base64Encoded: decodedPayload.key) else {
			throw JWEHelperError.invalidMasterkeyPayload
		}
		return try P384.KeyAgreement.PrivateKey(pkcs8DerRepresentation: privateKeyData)
	}
}

public extension P384.KeyAgreement.PrivateKey {
	init(pkcs8DerRepresentation: Data) throws {
		let privateKey = try ECPrivateKey(der: Array(pkcs8DerRepresentation), pkcs8: true)
		try self.init(pemRepresentation: privateKey.pem)
	}

	func derPkcs8() throws -> Data {
		let privateKey = try ECPrivateKey(pem: pemRepresentation)
		return Data(privateKey.derPkcs8)
	}
}
