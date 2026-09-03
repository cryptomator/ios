//
//  CloudProviderType+AccountRecovery.swift
//  Cryptomator
//
//  Created by Tobias Hagemann on 01.09.26.
//  Copyright © 2026 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import Foundation

/**
 How the user restores access to a cloud account when its credential no longer works.
 */
enum AccountRecoveryMode {
	/// Signing in again keeps the account, because the cloud identifies it.
	case reauthenticate
	/// The user edits the stored credential, because signing in again would mint a new identifier and thus a new account.
	case editExisting
	/// The account needs no credential.
	case unsupported
}

extension CloudProviderType {
	var accountRecoveryMode: AccountRecoveryMode {
		switch self {
		case .box, .dropbox, .googleDrive, .microsoftGraph, .pCloud:
			return .reauthenticate
		case .s3, .webDAV:
			return .editExisting
		case .localFileSystem:
			return .unsupported
		}
	}
}
