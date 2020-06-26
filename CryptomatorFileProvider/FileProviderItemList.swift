//
//  FileProviderItemList.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 25.06.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Foundation
import FileProvider
public struct FileProviderItemList {
	public let items: [FileProviderItem]
	public let nextPageToken: NSFileProviderPage?

	init(items: [FileProviderItem], nextPageToken: NSFileProviderPage?) {
		self.items = items
		self.nextPageToken = nextPageToken
	}
}
