//
//  VaultListPosition.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 11.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation
import GRDB

struct VaultListPosition: Codable {
	var id: Int64?
	var position: Int?
	let vaultUID: String
}

extension VaultListPosition: FetchableRecord, MutablePersistableRecord {
	static let databaseSelection: [SQLSelectable] = [AllColumns(), Column.rowID]

	mutating func didInsert(with rowID: Int64, for column: String?) {
		id = rowID
	}

	init(row: Row) {
		self.id = row[Column.rowID]
		self.position = row[Columns.position]
		self.vaultUID = row[Columns.vaultUID]
	}

	func encode(to container: inout PersistenceContainer) {
		container[Column.rowID] = id
		container[Columns.position] = position
		container[Columns.vaultUID] = vaultUID
	}

	enum Columns: String, ColumnExpression {
		case id, position, vaultUID
	}
}
