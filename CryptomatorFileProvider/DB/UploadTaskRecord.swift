//
//  UploadTaskRecord.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 01.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import FileProvider
import Foundation
import GRDB

struct UploadTaskRecord: Decodable, FetchableRecord, TableRecord {
	static let databaseTableName = "uploadTasks"
	static let correspondingItemKey = "correspondingItem"
	static let lastFailedUploadDateKey = "lastFailedUploadDate"
	static let uploadErrorCodeKey = "uploadErrorCode"
	static let uploadErrorDomainKey = "uploadErrorDomain"
	let correspondingItem: Int64
	var lastFailedUploadDate: Date?
	var uploadErrorCode: Int?
	var uploadErrorDomain: String?
	var failedWithError: Error? {
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

extension UploadTaskRecord: PersistableRecord {
	func encode(to container: inout PersistenceContainer) {
		container[UploadTaskRecord.correspondingItemKey] = correspondingItem
		container[UploadTaskRecord.lastFailedUploadDateKey] = lastFailedUploadDate
		container[UploadTaskRecord.uploadErrorCodeKey] = uploadErrorCode
		container[UploadTaskRecord.uploadErrorDomainKey] = uploadErrorDomain
	}
}

extension UploadTaskRecord {
	static let itemMetadata = belongsTo(ItemMetadata.self, key: "metadata")
	var itemMetadata: QueryInterfaceRequest<ItemMetadata> {
		request(for: UploadTaskRecord.itemMetadata)
	}
}
