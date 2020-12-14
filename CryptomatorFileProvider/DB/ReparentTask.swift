//
//  ReparentTask.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 22.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import Foundation
import GRDB
struct ReparentTask: Decodable, FetchableRecord, TableRecord {
	static let databaseTableName = "reparentTasks"
	static let correspondingItemKey = "correspondingItem"
	static let sourceCloudPathKey = "sourceCloudPath"
	static let targetCloudPathKey = "targetCloudPath"
	static let oldParentIdKey = "oldParentId"
	static let newParentIdKey = "newParentId"
	let correspondingItem: Int64
	let sourceCloudPath: CloudPath
	let targetCloudPath: CloudPath
	let oldParentId: Int64
	let newParentId: Int64
}

extension ReparentTask: PersistableRecord {
	func encode(to container: inout PersistenceContainer) {
		container[ReparentTask.correspondingItemKey] = correspondingItem
		container[ReparentTask.sourceCloudPathKey] = sourceCloudPath
		container[ReparentTask.targetCloudPathKey] = targetCloudPath
		container[ReparentTask.oldParentIdKey] = oldParentId
		container[ReparentTask.newParentIdKey] = newParentId
	}
}
