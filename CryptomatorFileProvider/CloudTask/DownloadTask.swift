//
//  DownloadTask.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 27.05.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation
import GRDB

struct DownloadTask: CloudTask {
	let replaceExisting: Bool
	let localURL: URL
	let itemMetadata: ItemMetadata
}
