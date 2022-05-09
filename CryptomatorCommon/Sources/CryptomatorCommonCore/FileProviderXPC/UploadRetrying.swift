//
//  UploadRetrying.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 03.05.22.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import FileProvider
import Foundation

@objc public protocol UploadRetrying: NSFileProviderServiceSource {
	/**
	 Retries the upload for the given item identifiers.
	  */
	func retryUpload(for itemIdentifiers: [NSFileProviderItemIdentifier], reply: @escaping (Error?) -> Void)

	func getCurrentFractionalUploadProgress(for itemIdentifier: NSFileProviderItemIdentifier, reply: @escaping (NSNumber?) -> Void)
}

public extension NSFileProviderServiceName {
	static let uploadRetryingService = NSFileProviderServiceName("org.cryptomator.ios.upload-retrying")
}
