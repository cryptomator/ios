//
//  GetFolderIntentHandlerError.swift
//  CryptomatorIntents
//
//  Created by Philipp Schmid on 24.05.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import Foundation

enum GetFolderIntentHandlerError: Error, LocalizedError {
	case missingPath
	case noVaultSelected

	var errorDescription: String? {
		switch self {
		case .missingPath:
			return LocalizedString.getValue("getFolderIntent.error.missingPath")
		case .noVaultSelected:
			return LocalizedString.getValue("getFolderIntent.error.noVaultSelected")
		}
	}
}
