//
//  VaultAccountManagerError+Localization.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 08.10.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation

extension VaultAccountManagerError: LocalizedError {
	public var errorDescription: String? {
		switch self {
		case .vaultAccountAlreadyExists:
			return LocalizedString.getValue("vaultAccountManager.error.vaultAccountAlreadyExists")
		}
	}
}
