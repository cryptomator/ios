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
	 Wraps an error in a `NSFileProviderError.notAuthenticated` object.

	 This is needed as only with this error the FileProvider UI (FPUIActionExtensionViewController) is called with a `prepare(forError:)`.

	 - Parameter error: The error, which should be wrapped into a `NSFileProviderError.notAuthenticated` object.
	 Note in order to switch on an error enum in the FileProviderExtensionUI it needs to be exported to Objective-C.
	 - Parameter domain: The FileProviderDomain where the error occurred.
	 */
	public static func wrapError(_ error: Error, domain: NSFileProviderDomain?) -> NSFileProviderError {
		var userInfo = [String: Any]()
		let underlyingError: Error
		if let unlockMonitorError = error as? UnlockMonitorError {
			underlyingError = unlockMonitorError.underlyingError
		} else {
			underlyingError = error
		}
		userInfo[NSUnderlyingErrorKey] = underlyingError
		if let vaultName = domain?.displayName {
			userInfo[VaultNameErrorKey] = vaultName
		}
		if let pathRelativeToDocumentStorage = domain?.pathRelativeToDocumentStorage {
			userInfo[PathRelativeToDocumentStorageErrorKey] = pathRelativeToDocumentStorage
		}
		if let domainIdentifier = domain?.identifier {
			userInfo[DomainIdentifierErrorKey] = domainIdentifier
		}
		if let localizedError = error as? LocalizedError {
			if let failureReason = localizedError.failureReason {
				userInfo[FileProviderLocalizedDescriptionErrorKey] = failureReason
			}
			if let recoverySuggestion = localizedError.recoverySuggestion {
				userInfo[FileProviderLocalizedActionErrorKey] = recoverySuggestion
			}
		}
		userInfo[FileProviderLocalizedTitleErrorKey] = error.localizedDescription
		return NSFileProviderError(.notAuthenticated, userInfo: userInfo)
	}
}

// swiftlint:disable identifier_name
public let VaultNameErrorKey = "vaultName"
public let PathRelativeToDocumentStorageErrorKey = "pathRelativeToDocumentStorage"
public let DomainIdentifierErrorKey = "domainIdentifier"

// MARK: Undocumented FileProviderError Keys

let FileProviderLocalizedDescriptionErrorKey = "NSFileProviderErrorDescription"
let FileProviderLocalizedTitleErrorKey = "NSFileProviderErrorTitle"
let FileProviderLocalizedActionErrorKey = "NSFileProviderErrorAction"
// swiftlint:enable identifier_name
