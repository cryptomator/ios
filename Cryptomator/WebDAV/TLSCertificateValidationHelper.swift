//
//  TLSCertificateValidationHelper.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 28.08.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation
import Promises

protocol TLSCertificateValidationHelping {
	func validate(url: URL) -> Promise<TLSCertificate>
}

struct TLSCertificateValidationHelper: TLSCertificateValidationHelping {
	func validate(url: URL) -> Promise<TLSCertificate> {
		let validator = TLSCertificateValidator(baseURL: url)
		return validator.validate()
	}
}
