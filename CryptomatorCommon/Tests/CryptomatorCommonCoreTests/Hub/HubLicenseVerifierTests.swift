//
//  HubLicenseVerifierTests.swift
//  CryptomatorCommonCoreTests
//
//  Created by Tobias Hagemann on 09.06.26.
//  Copyright © 2026 Skymatic GmbH. All rights reserved.
//

import CryptoKit
import Foundation
import JOSESwift
import Security
import XCTest
@testable import CryptomatorCommonCore

final class HubLicenseVerifierTests: XCTestCase {
	private var signingKey: P521.Signing.PrivateKey!
	private var publicKey: SecKey!

	override func setUpWithError() throws {
		signingKey = P521.Signing.PrivateKey()
		publicKey = try HubLicenseVerifier.makeSecKey(x963Representation: signingKey.publicKey.x963Representation, keyClass: kSecAttrKeyClassPublic)
	}

	func testValidSignatureNotExpired() throws {
		let token = try makeToken(signingKey: signingKey, claims: ["exp": Date().addingTimeInterval(3600).timeIntervalSince1970])

		let result = try HubLicenseVerifier.verify(token: token, publicKey: publicKey)

		XCTAssertEqual(result, .valid)
	}

	func testValidSignatureExpired() throws {
		let token = try makeToken(signingKey: signingKey, claims: ["exp": Date().addingTimeInterval(-3600).timeIntervalSince1970])

		let result = try HubLicenseVerifier.verify(token: token, publicKey: publicKey)

		XCTAssertEqual(result, .expired)
	}

	func testValidSignatureExpiredWithinLeewayStillValid() throws {
		let token = try makeToken(signingKey: signingKey, claims: ["exp": Date().addingTimeInterval(-30).timeIntervalSince1970])

		let result = try HubLicenseVerifier.verify(token: token, publicKey: publicKey)

		XCTAssertEqual(result, .valid)
	}

	func testValidSignatureExpiredBeyondLeewayExpired() throws {
		let token = try makeToken(signingKey: signingKey, claims: ["exp": Date().addingTimeInterval(-90).timeIntervalSince1970])

		let result = try HubLicenseVerifier.verify(token: token, publicKey: publicKey)

		XCTAssertEqual(result, .expired)
	}

	func testWrongKeyThrowsInvalidSignature() throws {
		let otherKey = P521.Signing.PrivateKey()
		let token = try makeToken(signingKey: otherKey, claims: ["exp": Date().addingTimeInterval(3600).timeIntervalSince1970])

		XCTAssertThrowsError(try HubLicenseVerifier.verify(token: token, publicKey: publicKey)) { error in
			guard case HubLicenseVerificationError.invalidSignature = error else {
				XCTFail("Unexpected error: \(error)")
				return
			}
		}
	}

	func testGarbledTokenThrowsMalformed() throws {
		XCTAssertThrowsError(try HubLicenseVerifier.verify(token: "not-a-valid-token", publicKey: publicKey)) { error in
			guard case HubLicenseVerificationError.malformed = error else {
				XCTFail("Unexpected error: \(error)")
				return
			}
		}
	}

	func testMissingExpirationThrowsMalformed() throws {
		let token = try makeToken(signingKey: signingKey, claims: ["sub": "test"])

		XCTAssertThrowsError(try HubLicenseVerifier.verify(token: token, publicKey: publicKey)) { error in
			guard case HubLicenseVerificationError.malformed = error else {
				XCTFail("Unexpected error: \(error)")
				return
			}
		}
	}

	func testWrongAlgorithmThrowsInvalidSignature() throws {
		let symmetricKey = Data(repeating: 0x01, count: 64)
		let header = JWSHeader(algorithm: .HS256)
		let payload = try Payload(JSONSerialization.data(withJSONObject: ["exp": Date().addingTimeInterval(3600).timeIntervalSince1970]))
		let signer = try XCTUnwrap(Signer(signingAlgorithm: .HS256, key: symmetricKey))
		let token = try JWS(header: header, payload: payload, signer: signer).compactSerializedString

		XCTAssertThrowsError(try HubLicenseVerifier.verify(token: token, publicKey: publicKey)) { error in
			guard case HubLicenseVerificationError.invalidSignature = error else {
				XCTFail("Unexpected error: \(error)")
				return
			}
		}
	}

	func testUnsignedAlgNoneTokenIsRejected() throws {
		let header = try JSONSerialization.data(withJSONObject: ["alg": "none"])
		let payload = try JSONSerialization.data(withJSONObject: ["exp": Date().addingTimeInterval(3600).timeIntervalSince1970])
		let token = "\(header.base64URLEncodedString()).\(payload.base64URLEncodedString())."

		XCTAssertThrowsError(try HubLicenseVerifier.verify(token: token, publicKey: publicKey)) { error in
			XCTAssertTrue(error is HubLicenseVerificationError, "Unexpected error: \(error)")
		}
	}

	func testEmbeddedPublicKeyRejectsForeignSignature() throws {
		// exercises the embedded production key: it must parse into a usable EC key and reject a token signed by a different key
		let token = try makeToken(signingKey: signingKey, claims: ["exp": Date().addingTimeInterval(3600).timeIntervalSince1970])

		XCTAssertThrowsError(try HubLicenseVerifier.verify(token: token)) { error in
			guard case HubLicenseVerificationError.invalidSignature = error else {
				XCTFail("Unexpected error: \(error)")
				return
			}
		}
	}

	// MARK: - Internal

	private func makeToken(signingKey: P521.Signing.PrivateKey, claims: [String: Any]) throws -> String {
		let privateKey = try HubLicenseVerifier.makeSecKey(x963Representation: signingKey.x963Representation, keyClass: kSecAttrKeyClassPrivate)
		let header = JWSHeader(algorithm: .ES512)
		let payload = try Payload(JSONSerialization.data(withJSONObject: claims))
		let signer = try XCTUnwrap(Signer(signingAlgorithm: .ES512, key: privateKey))
		let jws = try JWS(header: header, payload: payload, signer: signer)
		return jws.compactSerializedString
	}
}
