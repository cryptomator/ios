//
//  DocumentStorageURLProvider.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 05.10.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import FileProvider
import Foundation

public protocol DocumentStorageURLProvider {
	var documentStorageURL: URL { get }
}

extension NSFileProviderManager: DocumentStorageURLProvider {}
