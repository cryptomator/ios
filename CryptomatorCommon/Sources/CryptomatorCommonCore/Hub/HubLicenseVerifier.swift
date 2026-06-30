//
//  HubLicenseVerifier.swift
//  CryptomatorCommonCore
//
//  Created by Tobias Hagemann on 09.06.26.
//  Copyright © 2026 Skymatic GmbH. All rights reserved.
//

import CryptoKit
import Dependencies
import Foundation
import JOSESwift
import Security

public enum HubLicenseVerificationError: Error, LocalizedError {
	case invalidSignature
	case malformed

	public var errorDescription: String? {
		switch self {
		case .invalidSignature, .malformed:
			return LocalizedString.getValue("hubAuthentication.license.error.invalidSignature")
		}
	}
}

public enum HubLicenseVerificationResult: Equatable {
	case valid
	case expired
}

public enum HubLicenseVerifier {
	/// Static ES512 (P-521 / secp521r1) public key of Skymatic's License Server, base64-encoded SPKI (DER).
	private static let licensePublicKeyBase64 = "MIGbMBAGByqGSM49AgEGBSuBBAAjA4GGAAQBLJOU8YgKkP19EPV6p3eDlnpljZxDc2BXK+RPAb3caj2EuEH9a5ORaLAY+PjIkDPIQdHaa44Cbrzmug97bTyXTzQB97C90Utw0bzNkE22YwKdqWwKebUCSP3Tifxgn8JzrWb/9oI2D3q4+ZPzHZkty0SSM8kTwJwgT0wOwB4dj1GBEFc="

	/// Lenient clock-skew allowance for the `exp` check, mirroring the backend's tolerance.
	private static let leeway: TimeInterval = 60

	private static let embeddedPublicKey: SecKey = {
		do {
			guard let derData = Data(base64Encoded: licensePublicKeyBase64) else {
				throw HubLicenseVerificationError.malformed
			}
			let publicKey = try P521.Signing.PublicKey(derRepresentation: derData)
			return try makeSecKey(x963Representation: publicKey.x963Representation, keyClass: kSecAttrKeyClassPublic)
		} catch {
			fatalError("Embedded License Server public key is invalid: \(error)")
		}
	}()

	public static func verify(token: String) throws -> HubLicenseVerificationResult {
		try verify(token: token, publicKey: embeddedPublicKey)
	}

	static func verify(token: String, publicKey: SecKey) throws -> HubLicenseVerificationResult {
		let jws: JWS
		do {
			jws = try JWS(compactSerialization: token)
		} catch {
			throw HubLicenseVerificationError.malformed
		}
		guard let verifier = Verifier(verifyingAlgorithm: .ES512, key: publicKey) else {
			throw HubLicenseVerificationError.malformed
		}
		guard jws.isValid(for: verifier) else {
			throw HubLicenseVerificationError.invalidSignature
		}
		let expiration = try expirationDate(from: jws.payload)
		if expiration < Date().addingTimeInterval(-leeway) {
			return .expired
		}
		return .valid
	}

	static func makeSecKey(x963Representation: Data, keyClass: CFString) throws -> SecKey {
		let attributes: [CFString: Any] = [
			kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
			kSecAttrKeyClass: keyClass
		]
		var error: Unmanaged<CFError>?
		guard let secKey = SecKeyCreateWithData(x963Representation as CFData, attributes as CFDictionary, &error) else {
			if let error = error?.takeRetainedValue() {
				throw error
			}
			throw HubLicenseVerificationError.malformed
		}
		return secKey
	}

	private static func expirationDate(from payload: Payload) throws -> Date {
		do {
			let claims = try JSONDecoder().decode(LicenseClaims.self, from: payload.data())
			return Date(timeIntervalSince1970: claims.exp)
		} catch {
			throw HubLicenseVerificationError.malformed
		}
	}

	private struct LicenseClaims: Decodable {
		let exp: TimeInterval
	}
}

public protocol HubLicenseVerifying {
	func verify(token: String) throws -> HubLicenseVerificationResult
}

struct LiveHubLicenseVerifier: HubLicenseVerifying {
	func verify(token: String) throws -> HubLicenseVerificationResult {
		try HubLicenseVerifier.verify(token: token)
	}
}

private enum HubLicenseVerifyingDependencyKey: DependencyKey {
	static let liveValue: HubLicenseVerifying = LiveHubLicenseVerifier()
	#if DEBUG
	static let testValue: HubLicenseVerifying = UnimplementedHubLicenseVerifier()
	#endif
}

extension DependencyValues {
	var hubLicenseVerifier: HubLicenseVerifying {
		get { self[HubLicenseVerifyingDependencyKey.self] }
		set { self[HubLicenseVerifyingDependencyKey.self] = newValue }
	}
}

#if DEBUG
final class UnimplementedHubLicenseVerifier: HubLicenseVerifying {
	func verify(token: String) throws -> HubLicenseVerificationResult {
		unimplemented(placeholder: .valid)
	}
}

// MARK: - HubLicenseVerifyingMock -

final class HubLicenseVerifyingMock: HubLicenseVerifying {
	// MARK: - verify

	var verifyTokenThrowableError: Error?
	var verifyTokenCallsCount = 0
	var verifyTokenCalled: Bool {
		verifyTokenCallsCount > 0
	}

	var verifyTokenReceivedToken: String?
	var verifyTokenReturnValue: HubLicenseVerificationResult!
	var verifyTokenClosure: ((String) throws -> HubLicenseVerificationResult)?

	func verify(token: String) throws -> HubLicenseVerificationResult {
		if let error = verifyTokenThrowableError {
			throw error
		}
		verifyTokenCallsCount += 1
		verifyTokenReceivedToken = token
		return try verifyTokenClosure.map({ try $0(token) }) ?? verifyTokenReturnValue
	}
}
#endif
