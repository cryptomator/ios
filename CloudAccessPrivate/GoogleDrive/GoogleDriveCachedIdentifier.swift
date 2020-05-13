//
//  GoogleDriveCachedIdentifier.swift
//  CloudAccessPrivate
//
//  Created by Philipp Schmid on 11.05.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Foundation
import GRDB

class GoogleDriveCachedIdentifier: Record {
	var itemIdentifier: String
	var remoteURL: URL

	required init(row: Row) {
		self.itemIdentifier = row[Columns.itemIdentifier]
		self.remoteURL = URL(string: row[Columns.remoteURL])!
		super.init()
	}

	enum Columns: String, ColumnExpression {
		case itemIdentifier, remoteURL
	}

	override func encode(to container: inout PersistenceContainer) {
		container[Columns.itemIdentifier] = itemIdentifier
		container[Columns.remoteURL] = remoteURL.absoluteString
	}

	init(itemIdentifier: String, remoteURL: URL) {
		self.itemIdentifier = itemIdentifier
		self.remoteURL = remoteURL
		super.init()
	}

	override class var databaseTableName: String {
		"googleDriveCachedIdentifiers"
	}
}
