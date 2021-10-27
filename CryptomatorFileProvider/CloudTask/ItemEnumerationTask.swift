//
//  ItemEnumerationTask.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 29.05.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation
import GRDB

struct ItemEnumerationTask: CloudTask {
	let taskRecord: ItemEnumerationTaskRecord
	let itemMetadata: ItemMetadata

	enum CodingKeys: String, CodingKey {
		case taskRecord = "itemEnumerationTask"
		case itemMetadata
	}
}
