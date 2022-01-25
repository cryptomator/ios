//
//  ErrorWrapper.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 05.07.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import FileProvider
import Foundation

public enum ErrorWrapper {
	/**
	 Wraps an  error in a NSFileProviderError.notAuthenticated object as only with this error the FileProvider UI (FPUIActionExtensionViewController) is called with a prepare(forError error: Error).
	 */
	public static func wrapError(_ error: Error, domain: NSFileProviderDomain?) -> NSFileProviderError {
		var userInfo = [String: Any]()
		userInfo["internalError"] = error
		if let vaultName = domain?.displayName {
			userInfo["vaultName"] = vaultName
		}
		if let pathRelativeToDocumentStorage = domain?.pathRelativeToDocumentStorage {
			userInfo["pathRelativeToDocumentStorage"] = pathRelativeToDocumentStorage
		}
		if let domainIdentifier = domain?.identifier {
			userInfo["domainIdentifier"] = domainIdentifier
		}
		return NSFileProviderError(.notAuthenticated, userInfo: userInfo)
	}
}
