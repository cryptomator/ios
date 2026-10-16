//
//  TLSCertificateValidationHelperMock.swift
//  CryptomatorTests
//
//  Created by Philipp Schmid on 28.08.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation
@testable import Cryptomator

// swiftlint:disable all
final class TLSCertificateValidationHelpingMock: TLSCertificateValidationHelping {
	// MARK: - validate

	var validateUrlCallsCount = 0
	var validateUrlCalled: Bool {
		validateUrlCallsCount > 0
	}

	var validateUrlReceivedUrl: URL?
	var validateUrlReceivedInvocations: [URL] = []
	var validateUrlThrowableError: Error?
	var validateUrlReturnValue: TLSCertificate!
	var validateUrlClosure: ((URL) async throws -> TLSCertificate)?

	func validate(url: URL) async throws -> TLSCertificate {
		if let error = validateUrlThrowableError {
			throw error
		}
		validateUrlCallsCount += 1
		validateUrlReceivedUrl = url
		validateUrlReceivedInvocations.append(url)
		if let validateUrlClosure = validateUrlClosure {
			return try await validateUrlClosure(url)
		}
		return validateUrlReturnValue
	}
}

// swiftlint:enable all
