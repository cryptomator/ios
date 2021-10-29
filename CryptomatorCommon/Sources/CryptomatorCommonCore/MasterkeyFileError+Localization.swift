//
//  LocalizedCloudProviderDecorator.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 29.10.21.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCryptoLib
import Foundation
extension MasterkeyFileError: LocalizedError {
	public var errorDescription: String? {
		switch self {
		case .invalidPassphrase:
			return LocalizedString.getValue("MasterkeyFileError.invalidPassphrase")
		case .malformedMasterkeyFile:
			return nil
		case .keyDerivationFailed:
			return nil
		case .keyWrapFailed:
			return nil
		}
	}
}
