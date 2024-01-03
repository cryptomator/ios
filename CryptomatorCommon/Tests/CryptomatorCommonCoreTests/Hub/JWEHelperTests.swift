//
//  JWEHelperTests.swift
//  CryptomatorCommonCoreTests
//
//  Created by Philipp Schmid on 25.12.23.
//  Copyright © 2023 Skymatic GmbH. All rights reserved.

import CryptoKit
import CryptomatorCommonCore
import JOSESwift
import SwiftECC
import XCTest
@testable import CryptomatorCryptoLib

final class JWEHelperTests: XCTestCase {
	// key pairs from frontend tests (crypto.spec.ts):
	private let userPrivKey = "MIG2AgEAMBAGByqGSM49AgEGBSuBBAAiBIGeMIGbAgEBBDDCi4K1Ts3DgTz/ufkLX7EGMHjGpJv+WJmFgyzLwwaDFSfLpDw0Kgf3FKK+LAsV8r+hZANiAARLOtFebIjxVYUmDV09Q1sVxz2Nm+NkR8fu6UojVSRcCW13tEZatx8XGrIY9zC7oBCEdRqDc68PMSvS5RA0Pg9cdBNc/kgMZ1iEmEv5YsqOcaNADDSs0bLlXb35pX7Kx5Y="
	private let devicePrivKey = "MIG2AgEAMBAGByqGSM49AgEGBSuBBAAiBIGeMIGbAgEBBDB2bmFCWy2p+EbAn8NWS5Om+GA7c5LHhRZb8g2pSMSf0fsd7k7dZDVrnyHFiLdd/YGhZANiAAR6bsjTEdXKWIuu1Bvj6Y8wySlIROy7YpmVZTY128ItovCD8pcR4PnFljvAIb2MshCdr1alX4g6cgDOqcTeREiObcSfucOU9Ry1pJ/GnX6KA0eSljrk6rxjSDos8aiZ6Mg="

	// used for JWE generation in frontend: (jwe.spec.ts):
	private let privKey = "ME8CAQAwEAYHKoZIzj0CAQYFK4EEACIEODA2AgEBBDEA6QybmBitf94veD5aCLr7nlkF5EZpaXHCfq1AXm57AKQyGOjTDAF9EQB28fMywTDQ"

	override func setUpWithError() throws {}

	func testDecryptUserKeyECDHES() throws {
		let jwe = try JWE(compactSerialization: """
		eyJhbGciOiJFQ0RILUVTIiwiZW5jIjoiQTI1NkdDTSIsImVwayI6eyJrZXlfb3BzIjpbXSwiZXh0Ijp\
		0cnVlLCJrdHkiOiJFQyIsIngiOiJoeHpiSWh6SUJza3A5ZkZFUmJSQ2RfOU1fbWYxNElqaDZhcnNoVX\
		NkcEEyWno5ejZZNUs4NHpZR2I4b2FHemNUIiwieSI6ImJrMGRaNWhpelZ0TF9hN2hNejBjTUduNjhIR\
		jZFdWlyNHdlclNkTFV5QWd2NWUzVzNYSG5sdHJ2VlRyU3pzUWYiLCJjcnYiOiJQLTM4NCJ9LCJhcHUi\
		OiIiLCJhcHYiOiIifQ..pu3Q1nR_yvgRAapG.4zW0xm0JPxbcvZ66R-Mn3k841lHelDQfaUvsZZAtWs\
		L2w4FMi6H_uu6ArAWYLtNREa_zfcPuyuJsFferYPSNRUWt4OW6aWs-l_wfo7G1ceEVxztQXzQiwD30U\
		TA8OOdPcUuFfEq2-d9217jezrcyO6m6FjyssEZIrnRArUPWKzGdghXccGkkf0LTZcGJoHeKal-RtyP8\
		PfvEAWTjSOCpBlSdUJ-1JL3tyd97uVFNaVuH3i7vvcMoUP_bdr0XW3rvRgaeC6X4daPLUvR1hK5Msut\
		QMtM2vpFghS_zZxIQRqz3B2ECxa9Bjxhmn8kLX5heZ8fq3lH-bmJp1DxzZ4V1RkWk.yVwXG9yARa5Ih\
		q2koh2NbQ
		""")

		let data = Data(base64Encoded: devicePrivKey)!
		let privateKey = try P384.KeyAgreement.PrivateKey(pkcs8DerRepresentation: data)
		let userKey = try JWEHelper.decryptUserKey(jwe: jwe, privateKey: privateKey)

		let x = userKey.x963Representation[1 ..< 49]
		let y = userKey.x963Representation[49 ..< 97]
		let k = userKey.x963Representation[97 ..< 145]

		/// PKSCS #8: MIG2AgEAMBAGByqGSM49AgEGBSuBBAAiBIGeMIGbAgEBBDDCi4K1Ts3DgTz/ufkLX7EGMHjGpJv+WJmFgyzLwwaDFSfLpDw0Kgf3FKK+LAsV8r+hZANiAARLOtFebIjxVYUmDV09Q1sVxz2Nm+NkR8fu6UojVSRcCW13tEZatx8XGrIY9zC7oBCEdRqDc68PMSvS5RA0Pg9cdBNc/kgMZ1iEmEv5YsqOcaNADDSs0bLlXb35pX7Kx5Y=
		/// see: (crypto.spec.ts) in the Hub Frontend
		XCTAssertEqual(x.base64URLEncodedString(), "SzrRXmyI8VWFJg1dPUNbFcc9jZvjZEfH7ulKI1UkXAltd7RGWrcfFxqyGPcwu6AQ")
		XCTAssertEqual(y.base64URLEncodedString(), "hHUag3OvDzEr0uUQND4PXHQTXP5IDGdYhJhL-WLKjnGjQAw0rNGy5V29-aV-yseW")
		XCTAssertEqual(k.base64URLEncodedString(), "wouCtU7Nw4E8_7n5C1-xBjB4xqSb_liZhYMsy8MGgxUny6Q8NCoH9xSiviwLFfK_")
	}

	func testDecryptUserKeyECDHESWrongKey() throws {
		let jwe = try JWE(compactSerialization: """
		eyJhbGciOiJFQ0RILUVTIiwiZW5jIjoiQTI1NkdDTSIsImVwayI6eyJrZXlfb3BzIjpbXSwiZXh0Ijp\
		0cnVlLCJrdHkiOiJFQyIsIngiOiJoeHpiSWh6SUJza3A5ZkZFUmJSQ2RfOU1fbWYxNElqaDZhcnNoVX\
		NkcEEyWno5ejZZNUs4NHpZR2I4b2FHemNUIiwieSI6ImJrMGRaNWhpelZ0TF9hN2hNejBjTUduNjhIR\
		jZFdWlyNHdlclNkTFV5QWd2NWUzVzNYSG5sdHJ2VlRyU3pzUWYiLCJjcnYiOiJQLTM4NCJ9LCJhcHUi\
		OiIiLCJhcHYiOiIifQ..pu3Q1nR_yvgRAapG.4zW0xm0JPxbcvZ66R-Mn3k841lHelDQfaUvsZZAtWs\
		L2w4FMi6H_uu6ArAWYLtNREa_zfcPuyuJsFferYPSNRUWt4OW6aWs-l_wfo7G1ceEVxztQXzQiwD30U\
		TA8OOdPcUuFfEq2-d9217jezrcyO6m6FjyssEZIrnRArUPWKzGdghXccGkkf0LTZcGJoHeKal-RtyP8\
		PfvEAWTjSOCpBlSdUJ-1JL3tyd97uVFNaVuH3i7vvcMoUP_bdr0XW3rvRgaeC6X4daPLUvR1hK5Msut\
		QMtM2vpFghS_zZxIQRqz3B2ECxa9Bjxhmn8kLX5heZ8fq3lH-bmJp1DxzZ4V1RkWk.yVwXG9yARa5Ih\
		q2koh2NbQ
		""")

		let data = Data(base64Encoded: userPrivKey)!
		let privateKey = try P384.KeyAgreement.PrivateKey(pkcs8DerRepresentation: data)

		XCTAssertThrowsError(try JWEHelper.decryptUserKey(jwe: jwe, privateKey: privateKey)) { error in
			guard case JOSESwiftError.decryptingFailed = error else {
				XCTFail("Unexpected error: \(error)")
				return
			}
		}
	}

	func testDecryptUserKeyPBES2() throws {
		let jwe = try JWE(compactSerialization: """
		eyJhbGciOiJQQkVTMi1IUzUxMitBMjU2S1ciLCJlbmMiOiJBMjU2R0NNIiwicDJzIjoiT3hMY0Q\
		xX1pCODc1c2hvUWY2Q1ZHQSIsInAyYyI6MTAwMCwiYXB1IjoiIiwiYXB2IjoiIn0.FD4fcrP4Pb\
		aKOQ9ZfXl0gpMM6Fa2rfqAvL0K5ZyYUiVeHCNV-A02Rg.urT1ShSv6qQxh8X7.gEqAiUWD98a2E\
		P7ITCPTw4DJo6-BpqrxA73D6gNIj9z4d1hN-EP99Q4mWBWLH97H8ugbG5rGsm8xsjsBqpWORQqF\
		mJZR2AhlPiwFaC7n_MDDBupSy_swDnCfj731Lal297IP5WbkFcmozKsyhmwdkctxjf_VHA.fJki\
		kDjUaxwUKqpvT7qaAQ
		""")

		let userKey = try JWEHelper.decryptUserKey(jwe: jwe, setupCode: "123456")

		let x = userKey.x963Representation[1 ..< 49]
		let y = userKey.x963Representation[49 ..< 97]
		let k = userKey.x963Representation[97 ..< 145]

		/// PKSCS #8: ME8CAQAwEAYHKoZIzj0CAQYFK4EEACIEODA2AgEBBDEA6QybmBitf94veD5aCLr7nlkF5EZpaXHCfq1AXm57AKQyGOjTDAF9EQB28fMywTDQ
		/// see: (jwe.spec.ts) in the Hub Frontend
		XCTAssertEqual(x.base64URLEncodedString(), "RxQR-NRN6Wga01370uBBzr2NHDbKIC56tPUEq2HX64RhITGhii8Zzbkb1HnRmdF0")
		XCTAssertEqual(y.base64URLEncodedString(), "aq6uqmUy4jUhuxnKxsv59A6JeK7Unn-mpmm3pQAygjoGc9wrvoH4HWJSQYUlsXDu")
		XCTAssertEqual(k.base64URLEncodedString(), "6QybmBitf94veD5aCLr7nlkF5EZpaXHCfq1AXm57AKQyGOjTDAF9EQB28fMywTDQ")
	}

	func testDecryptUserKeyPBES2WrongKey() throws {
		let jwe = try JWE(compactSerialization: """
		eyJhbGciOiJQQkVTMi1IUzUxMitBMjU2S1ciLCJlbmMiOiJBMjU2R0NNIiwicDJzIjoiT3hMY0Q\
		xX1pCODc1c2hvUWY2Q1ZHQSIsInAyYyI6MTAwMCwiYXB1IjoiIiwiYXB2IjoiIn0.FD4fcrP4Pb\
		aKOQ9ZfXl0gpMM6Fa2rfqAvL0K5ZyYUiVeHCNV-A02Rg.urT1ShSv6qQxh8X7.gEqAiUWD98a2E\
		P7ITCPTw4DJo6-BpqrxA73D6gNIj9z4d1hN-EP99Q4mWBWLH97H8ugbG5rGsm8xsjsBqpWORQqF\
		mJZR2AhlPiwFaC7n_MDDBupSy_swDnCfj731Lal297IP5WbkFcmozKsyhmwdkctxjf_VHA.fJki\
		kDjUaxwUKqpvT7qaAQ
		""")

		XCTAssertThrowsError(try JWEHelper.decryptUserKey(jwe: jwe, setupCode: "654321")) { error in
			guard case JOSESwiftError.decryptingFailed = error else {
				XCTFail("Unexpected error: \(error)")
				return
			}
		}
	}

	func testDecryptVaultKey() throws {
		let jwe = try JWE(compactSerialization: """
		eyJhbGciOiJFQ0RILUVTIiwiZW5jIjoiQTI1NkdDTSIsImVwayI6eyJrdHkiOiJFQyIsImNydiI6IlA\
		tMzg0Iiwia2V5X29wcyI6W10sImV4dCI6dHJ1ZSwieCI6IllUcEY3bGtTc3JvZVVUVFdCb21LNzBTN0\
		FhVTJyc0ptMURpZ1ZzbjRMY2F5eUxFNFBabldkYmFVcE9jQVV5a1ciLCJ5IjoiLU5pS3loUktjSk52N\
		m02Z0ZJUWc4cy1Xd1VXUW9uT3A5dkQ4cHpoa2tUU3U2RzFlU2FUTVlhZGltQ2Q4V0ExMSJ9LCJhcHUi\
		OiIiLCJhcHYiOiIifQ..BECWGzd9UvhHcTJC.znt4TlS-qiNEjxiu2v-du_E1QOBnyBR6LCt865SHxD\
		-kwRc1JwX_Lq9XVoFj2GnK9-9CgxhCLGurg5Jt9g38qv2brGAzWL7eSVeY1fIqdO_kUhLpGslRTN6h2\
		U0NHJi2-iE.WDVI2kOk9Dy3PWHyIg8gKA
		""")

		let data = Data(base64Encoded: privKey)!
		let privateKey = try P384.KeyAgreement.PrivateKey(pkcs8DerRepresentation: data)
		let masterkey = try JWEHelper.decryptVaultKey(jwe: jwe, with: privateKey)

		let expectedEncKey = [UInt8](repeating: 0x55, count: 32)
		let expectedMacKey = [UInt8](repeating: 0x77, count: 32)

		XCTAssertEqual(masterkey.aesMasterKey, expectedEncKey)
		XCTAssertEqual(masterkey.macMasterKey, expectedMacKey)
	}

	func testDecryptInvalidVaultKey_wrongKey() throws {
		let jwe = try JWE(compactSerialization: """
		eyJhbGciOiJFQ0RILUVTIiwiZW5jIjoiQTI1NkdDTSIsImVwayI6eyJrdHkiOiJFQyIsImNydiI6IlAtMzg0Iiwia2V5X29wcyI6W10sImV4dCI6dHJ1ZSwieCI6ImdodGR3VnNoUU8wRGFBdjVBOXBiZ1NCTW0yYzZKWVF4dkloR3p6RVdQTncxczZZcEFYeTRQTjBXRFJUWExtQ2wiLCJ5IjoiN3Rncm1Gd016NGl0ZmVQNzBndkpLcjRSaGdjdENCMEJHZjZjWE9WZ2M0bjVXMWQ4dFgxZ1RQakdrczNVSm1zUiJ9LCJhcHUiOiIiLCJhcHYiOiIifQ..x6JWRGSojUJUJYpp.5BRuzcaV.lLIhGH7Wz0n_iTBAubDFZA
		""")

		let data = Data(base64Encoded: privKey)!
		let privateKey = try P384.KeyAgreement.PrivateKey(pkcs8DerRepresentation: data)

		XCTAssertThrowsError(try JWEHelper.decryptVaultKey(jwe: jwe, with: privateKey)) { error in
			guard case JOSESwiftError.decryptingFailed = error else {
				XCTFail("Unexpected error: \(error)")
				return
			}
		}
	}

	func testDecryptInvalidVaultKey_payloadIsNotJSON() throws {
		let jwe = try JWE(compactSerialization: """
		eyJhbGciOiJFQ0RILUVTIiwiZW5jIjoiQTI1NkdDTSIsImVwayI6eyJrdHkiOiJFQyIsImNydiI6IlAtMzg0Iiwia2V5X29wcyI6W10sImV4dCI6dHJ1ZSwieCI6IkM2bWhsNE5BTHhEdHMwUlFlNXlyZWxQVDQyOGhDVzJNeUNYS3EwdUI0TDFMdnpXRHhVaVk3YTdZcEhJakJXcVoiLCJ5IjoiakM2dWc1NE9tbmdpNE9jUk1hdkNrczJpcFpXQjdkUmotR3QzOFhPSDRwZ2tpQ0lybWNlUnFxTnU3Z0c3Qk1yOSJ9LCJhcHUiOiIiLCJhcHYiOiIifQ..HNJJghL-SvERFz2v.N0z8YwFg.rYw29iX4i8XujdM4P4KKWg
		""")

		let data = Data(base64Encoded: privKey)!
		let privateKey = try P384.KeyAgreement.PrivateKey(pkcs8DerRepresentation: data)

		XCTAssertThrowsError(try JWEHelper.decryptVaultKey(jwe: jwe, with: privateKey)) { error in
			guard case DecodingError.dataCorrupted = error else {
				XCTFail("Unexpected error: \(error)")
				return
			}
		}
	}

	func testDecryptInvalidVaultKey_jsonDoesNotContainKey() throws {
		let jwe = try JWE(compactSerialization: """
		eyJhbGciOiJFQ0RILUVTIiwiZW5jIjoiQTI1NkdDTSIsImVwayI6eyJrdHkiOiJFQyIsImNydiI6IlAtMzg0Iiwia2V5X29wcyI6W10sImV4dCI6dHJ1ZSwieCI6InB3R05vcXRnY093MkJ6RDVmSnpBWDJvMzUwSWNsY3A5cFdVTHZ5VDRqRWVCRWdCc3hhTVJXQ1ZyNlJMVUVXVlMiLCJ5IjoiZ2lIVEE5MlF3VU5lbmg1OFV1bWFfb09BX3hnYmFDVWFXSlRnb3Z4WjU4R212TnN4eUlQRElLSm9WV1h5X0R6OSJ9LCJhcHUiOiIiLCJhcHYiOiIifQ..jDbzdI7d67_cUjGD.01BPnMq_tQ.aG_uFA6FYqoPS64QAJ4VBQ
		""")

		let data = Data(base64Encoded: privKey)!
		let privateKey = try P384.KeyAgreement.PrivateKey(pkcs8DerRepresentation: data)

		XCTAssertThrowsError(try JWEHelper.decryptVaultKey(jwe: jwe, with: privateKey)) { error in
			guard case DecodingError.keyNotFound = error else {
				XCTFail("Unexpected error: \(error)")
				return
			}
		}
	}

	func testDecryptInvalidVaultKey_jsonKeyIsNotAString() throws {
		let jwe = try JWE(compactSerialization: """
		eyJhbGciOiJFQ0RILUVTIiwiZW5jIjoiQTI1NkdDTSIsImVwayI6eyJrdHkiOiJFQyIsImNydiI6IlAtMzg0Iiwia2V5X29wcyI6W10sImV4dCI6dHJ1ZSwieCI6IkJyYm9UQkl5Y0NDUEdJQlBUekU2RjBnbTRzRjRCamZPN1I0a2x0aWlCaThKZkxxcVdXNVdUSVBLN01yMXV5QVUiLCJ5IjoiNUpGVUI0WVJiYjM2RUZpN2Y0TUxMcFFyZXd2UV9Tc3dKNHRVbFd1a2c1ZU04X1ZyM2pkeml2QXI2WThRczVYbSJ9LCJhcHUiOiIiLCJhcHYiOiIifQ..QEq4Z2m6iwBx2ioS.IBo8TbKJTS4pug.61Z-agIIXgP8bX10O_yEMA
		""")

		let data = Data(base64Encoded: privKey)!
		let privateKey = try P384.KeyAgreement.PrivateKey(pkcs8DerRepresentation: data)

		XCTAssertThrowsError(try JWEHelper.decryptVaultKey(jwe: jwe, with: privateKey)) { error in
			guard case DecodingError.typeMismatch = error else {
				XCTFail("Unexpected error: \(error)")
				return
			}
		}
	}

	func testDecryptInvalidVaultKey_invalidBase64Data() throws {
		let jwe = try JWE(compactSerialization: """
		eyJhbGciOiJFQ0RILUVTIiwiZW5jIjoiQTI1NkdDTSIsImVwayI6eyJrdHkiOiJFQyIsImNydiI6IlAtMzg0Iiwia2V5X29wcyI6W10sImV4dCI6dHJ1ZSwieCI6ImNZdlVFZm9LYkJjenZySE5zQjUxOGpycUxPMGJDOW5lZjR4NzFFMUQ5dk95MXRqd1piZzV3cFI0OE5nU1RQdHgiLCJ5IjoiaWRJekhCWERzSzR2NTZEeU9yczJOcDZsSG1zb29fMXV0VTlzX3JNdVVkbkxuVXIzUXdLZkhYMWdaVXREM1RKayJ9LCJhcHUiOiIiLCJhcHYiOiIifQ..0VZqu5ei9U3blGtq.eDvhU6drw7mIwvXu6Q.f05QnhI7JWG3IYHvexwdFQ
		""")

		let data = Data(base64Encoded: privKey)!
		let privateKey = try P384.KeyAgreement.PrivateKey(pkcs8DerRepresentation: data)

		XCTAssertThrowsError(try JWEHelper.decryptVaultKey(jwe: jwe, with: privateKey)) { error in
			guard case JWEHelperError.invalidMasterkeyPayload = error else {
				XCTFail("Unexpected error: \(error)")
				return
			}
		}
	}
}
