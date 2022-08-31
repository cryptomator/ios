//
//  TLSCertificateValidationHelperMock.swift
//  CryptomatorTests
//
//  Created by Philipp Schmid on 28.08.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation
import Promises
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
	var validateUrlReturnValue: Promise<TLSCertificate>!
	var validateUrlClosure: ((URL) -> Promise<TLSCertificate>)?

	func validate(url: URL) -> Promise<TLSCertificate> {
		validateUrlCallsCount += 1
		validateUrlReceivedUrl = url
		validateUrlReceivedInvocations.append(url)
		return validateUrlClosure.map({ $0(url) }) ?? validateUrlReturnValue
	}
}

// swiftlint:enable all
