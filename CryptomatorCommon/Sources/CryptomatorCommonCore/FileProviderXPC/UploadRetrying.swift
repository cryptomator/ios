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

public extension UploadRetrying {
	func retryUpload(for itemIdentifiers: [NSFileProviderItemIdentifier]) async throws {
		try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
			self.retryUpload(for: itemIdentifiers, reply: { error in
				if let error = error {
					continuation.resume(throwing: error)
				} else {
					continuation.resume()
				}
			})
		}
	}

	/**
	 Throws `CancellationError` as soon as the task is cancelled, even while the reply is outstanding.
	 */
	func getCurrentFractionalUploadProgress(for itemIdentifier: NSFileProviderItemIdentifier) async throws -> Double? {
		let fractionalProgress = OneShotSignal<Double?>()
		getCurrentFractionalUploadProgress(for: itemIdentifier, reply: { number in
			fractionalProgress.fulfill(number?.doubleValue)
		})
		return try await fractionalProgress.value
	}
}

public extension NSFileProviderServiceName {
	static let uploadRetryingService = NSFileProviderServiceName("org.cryptomator.ios.upload-retrying")
}
