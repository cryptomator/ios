//
//  UploadTask.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 08.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import GRDB

struct UploadTask: CloudTask, FetchableRecord, Decodable {
	let task: UploadTaskRecord
	let itemMetadata: ItemMetadata

	enum CodingKeys: String, CodingKey {
		case task = "uploadTask"
		case itemMetadata = "metadata"
	}
}
