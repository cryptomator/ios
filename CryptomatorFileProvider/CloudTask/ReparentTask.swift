//
//  ReparentTask.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 22.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import GRDB

struct ReparentTask: CloudTask, FetchableRecord, Decodable {
	let taskRecord: ReparentTaskRecord
	let itemMetadata: ItemMetadata

	enum CodingKeys: String, CodingKey {
		case taskRecord = "reparentTask"
		case itemMetadata
	}
}
