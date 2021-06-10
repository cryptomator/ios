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

	enum Columns: String, ColumnExpression {
		case correspondingItem, lastFailedUploadDate, uploadErrorCode, uploadErrorDomain
	}
}

extension UploadTaskRecord: PersistableRecord {
	func encode(to container: inout PersistenceContainer) {
		container[Columns.correspondingItem] = correspondingItem
		container[Columns.lastFailedUploadDate] = lastFailedUploadDate
		container[Columns.uploadErrorCode] = uploadErrorCode
		container[Columns.uploadErrorDomain] = uploadErrorDomain
	}
}

extension UploadTaskRecord {
	static let itemMetadata = belongsTo(ItemMetadata.self)
	var itemMetadata: QueryInterfaceRequest<ItemMetadata> {
		request(for: UploadTaskRecord.itemMetadata)
	}
}
