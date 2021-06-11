//
//  DeletionTask.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 12.09.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import GRDB

struct DeletionTask: CloudTask, FetchableRecord, Decodable {
	let taskRecord: DeletionTaskRecord
	let itemMetadata: ItemMetadata

	enum CodingKeys: String, CodingKey {
		case taskRecord = "deletionTask"
		case itemMetadata
	}
}
