//
//  IntegrationTestError.swift
//  CryptomatorIntegrationTests
//
//  Created by Philipp Schmid on 13.05.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Foundation

enum IntegrationTestError: Error {
	case providerNotSupported
	case environmentVariableNotSet
}
