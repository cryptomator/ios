//
//  ReparentTask.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 22.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Foundation
import GRDB
struct ReparentTask: Decodable, FetchableRecord, TableRecord {
	static let databaseTableName = "reparentTasks"
	static let correspondingItemKey = "correspondingItem"
	static let oldRemoteURLKey = "oldRemoteURL"
	static let newRemoteURLKey = "newRemoteURL"
	static let oldParentIdKey = "oldParentId"
	static let newParentIdKey = "newParentId"
	let correspondingItem: Int64
	let oldRemoteURL: URL
	let newRemoteURL: URL
	let oldParentId: Int64
	let newParentId: Int64
}

extension ReparentTask: PersistableRecord {
	func encode(to container: inout PersistenceContainer) {
		container[ReparentTask.correspondingItemKey] = correspondingItem
		container[ReparentTask.oldRemoteURLKey] = oldRemoteURL
		container[ReparentTask.newRemoteURLKey] = newRemoteURL
		container[ReparentTask.oldParentIdKey] = oldParentId
		container[ReparentTask.newParentIdKey] = newParentId
	}
}
