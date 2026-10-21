//
//  TLSCertificateValidationHelper.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 28.08.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation

protocol TLSCertificateValidationHelping {
	func validate(url: URL) async throws -> TLSCertificate
}

struct TLSCertificateValidationHelper: TLSCertificateValidationHelping {
	func validate(url: URL) async throws -> TLSCertificate {
		let validator = TLSCertificateValidator(baseURL: url)
		return try await validator.validate()
	}
}
