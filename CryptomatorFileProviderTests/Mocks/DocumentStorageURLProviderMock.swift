//
//  DocumentStorageURLProviderMock.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 04.03.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorFileProvider
import Foundation

class DocumentStorageURLProviderMock: DocumentStorageURLProvider {
	private let tmpDirURL: URL

	init(tmpDirURL: URL) {
		self.tmpDirURL = tmpDirURL
	}

	var documentStorageURL: URL {
		return tmpDirURL
	}
}
