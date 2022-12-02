//
//  ItemEnumerationTaskManagerTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 19.10.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import GRDB
import XCTest
@testable import CryptomatorFileProvider

class ItemEnumerationTaskManagerTests: XCTestCase {
	var manager: ItemEnumerationTaskDBManager!
	var itemMetadataManager: ItemMetadataDBManager!
	var inMemoryDB: DatabaseQueue!

	override func setUpWithError() throws {
		inMemoryDB = DatabaseQueue()
		try DatabaseHelper.migrate(inMemoryDB)
		manager = try ItemEnumerationTaskDBManager(database: inMemoryDB)
		itemMetadataManager = ItemMetadataDBManager(database: inMemoryDB)
	}

	func testCreateAndGetTaskRecord() throws {
		let cloudPath = CloudPath("/Test")
		let itemMetadata = ItemMetadata(name: "Test", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)
		try itemMetadataManager.cacheMetadata(itemMetadata)
		let pageToken: String? = nil
		let createdTask = try manager.createTask(for: itemMetadata, pageToken: pageToken)
		let fetchedTask = try getTaskRecord(for: itemMetadata.id!)
		XCTAssertEqual(fetchedTask, createdTask.taskRecord)
		XCTAssertEqual(itemMetadata.id, fetchedTask.correspondingItem)
		XCTAssertEqual(pageToken, fetchedTask.pageToken)
	}

	private func getTaskRecord(for id: Int64) throws -> ItemEnumerationTaskRecord {
		try inMemoryDB.read({ db in
			guard let task = try ItemEnumerationTaskRecord.fetchOne(db, key: id) else {
				throw DBManagerError.taskNotFound
			}
			return task
		})
	}
}

extension ItemEnumerationTaskRecord: Equatable {
	public static func == (lhs: ItemEnumerationTaskRecord, rhs: ItemEnumerationTaskRecord) -> Bool {
		return lhs.correspondingItem == rhs.correspondingItem && lhs.pageToken == rhs.pageToken
	}
}

extension ItemEnumerationTask: Equatable {
	public static func == (lhs: ItemEnumerationTask, rhs: ItemEnumerationTask) -> Bool {
		lhs.taskRecord == rhs.taskRecord && lhs.itemMetadata == rhs.itemMetadata
	}
}
