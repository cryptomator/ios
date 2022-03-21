//
//  VaultProviderFactory+Localization.swift
//  CryptomatorCommonCore
//
//  Created by Tobias Hagemann on 19.07.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation

extension VaultProviderFactoryError: LocalizedError {
	public var errorDescription: String? {
		switch self {
		case .unsupportedVaultConfig:
			return LocalizedString.getValue("vaultProviderFactory.error.unsupportedVaultConfig")
		case let .unsupportedVaultVersion(version):
			return String(format: LocalizedString.getValue("vaultProviderFactory.error.unsupportedVaultVersion"), version)
		}
	}
}
