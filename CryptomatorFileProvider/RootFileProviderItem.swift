//
//  RootFileProviderItem.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 11.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import FileProvider
import Foundation
import MobileCoreServices

public class RootFileProviderItem: NSObject, NSFileProviderItem {
	public var itemIdentifier = NSFileProviderItemIdentifier.rootContainer
	public let parentItemIdentifier = NSFileProviderItemIdentifier.rootContainer
	public let filename = "Cryptomator"
	public let typeIdentifier = kUTTypeFolder as String
	public let documentSize: NSNumber? = nil
	public var capabilities: NSFileProviderItemCapabilities {
		if fullVersionChecker.isFullVersion {
			return [.allowsAll]
		} else {
			return FileProviderItem.readOnlyCapabilities
		}
	}

	private let fullVersionChecker: FullVersionChecker
	override public convenience init() {
		self.init(fullVersionChecker: GlobalFullVersionChecker.default)
	}

	init(fullVersionChecker: FullVersionChecker) {
		self.fullVersionChecker = fullVersionChecker
	}
}
