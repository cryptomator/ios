//
//  UploadTask.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 08.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Foundation
import GRDB

struct UploadTask: Decodable, FetchableRecord, TableRecord {
	static let databaseTableName = "uploadTasks"
	static let correspondingItemKey = "correspondingItem"
	static let lastFailedUploadDateKey = "lastFailedUploadDate"
	static let uploadErrorCodeKey = "uploadErrorCode"
	static let uploadErrorDomainKey = "uploadErrorDomain"
	let correspondingItem: Int64
	var lastFailedUploadDate: Date?
	var uploadErrorCode: Int?
	var uploadErrorDomain: String?
	var error: Error? {
		guard let errorCode = uploadErrorCode, let errorDomain = uploadErrorDomain else {
			return nil
		}
		switch errorDomain {
		case NSFileProviderErrorDomain:
			if let fileProviderErrorCode = NSFileProviderError.Code(rawValue: errorCode) {
				return NSFileProviderError(fileProviderErrorCode)
			}
			return NSError(domain: errorDomain, code: errorCode, userInfo: nil)
		case NSCocoaErrorDomain:
			return CocoaError(CocoaError.Code(rawValue: errorCode))
		default:
			return NSError(domain: errorDomain, code: errorCode, userInfo: nil)
		}
	}
}

extension UploadTask: PersistableRecord {
	func encode(to container: inout PersistenceContainer) {
		container[UploadTask.correspondingItemKey] = correspondingItem
		container[UploadTask.lastFailedUploadDateKey] = lastFailedUploadDate
		container[UploadTask.uploadErrorCodeKey] = uploadErrorCode
		container[UploadTask.uploadErrorDomainKey] = uploadErrorDomain
	}
}
