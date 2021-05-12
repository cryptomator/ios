//
//  AccountListPosition.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 19.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import Foundation
import GRDB

struct AccountListPosition: Codable {
	var id: Int64?
	var position: Int?
	let accountUID: String
}

extension AccountListPosition: FetchableRecord, MutablePersistableRecord {
	static let databaseSelection: [SQLSelectable] = [AllColumns(), Column.rowID]
	static let account = belongsTo(CloudProviderAccount.self)

	mutating func didInsert(with rowID: Int64, for column: String?) {
		id = rowID
	}

	init(row: Row) {
		self.id = row[Column.rowID]
		self.position = row[Columns.position]
		self.accountUID = row[Columns.accountUID]
	}

	func encode(to container: inout PersistenceContainer) {
		container[Column.rowID] = id
		container[Columns.position] = position
		container[Columns.accountUID] = accountUID
	}

	enum Columns: String, ColumnExpression {
		case id, position, accountUID
	}
}
