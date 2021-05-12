//
//  FileProviderDecoratorTestCase.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 15.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import FileProvider
import XCTest
@testable import CryptomatorFileProvider

class FileProviderDecoratorTestCase: XCTestCase {
	var decorator: FileProviderDecorator!
	var mockedProvider: CloudProviderMock!
	var tmpDirectory: URL!
	override func setUpWithError() throws {
		mockedProvider = CloudProviderMock()
		let domainIdentifier = NSFileProviderDomainIdentifier("test")
		let domain = NSFileProviderDomain(identifier: domainIdentifier, displayName: "", pathRelativeToDocumentStorage: "")
		guard let manager = NSFileProviderManager(for: domain) else {
			XCTFail("Manager is nil")
			return
		}
		decorator = try FileProviderDecoratorMock(with: mockedProvider, for: domain, with: manager)
		tmpDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: tmpDirectory, withIntermediateDirectories: false, attributes: nil)
	}

	override func tearDownWithError() throws {
		try FileManager.default.removeItem(at: tmpDirectory)
	}
}

extension FileProviderItem {
	override open func isEqual(_ object: Any?) -> Bool {
		let other = object as? FileProviderItem
		return filename == other?.filename && itemIdentifier == other?.itemIdentifier && parentItemIdentifier == other?.parentItemIdentifier && typeIdentifier == other?.typeIdentifier && capabilities == other?.capabilities && documentSize == other?.documentSize
	}
}
