//
//  FileProviderItemList.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 25.06.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import FileProvider
import Foundation

public struct FileProviderItemList {
	public let items: [FileProviderItem]
	public let nextPageToken: NSFileProviderPage?
}
