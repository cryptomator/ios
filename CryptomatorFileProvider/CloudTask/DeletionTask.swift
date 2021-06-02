//
//  DeletionTask.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 12.09.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import GRDB

struct DeletionTask: CloudTask, FetchableRecord, Decodable {
	let task: DeletionTaskRecord
	let itemMetadata: ItemMetadata

	enum CodingKeys: String, CodingKey {
		case task = "deletionTask"
		case itemMetadata = "metadata"
	}
}
