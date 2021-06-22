//
//  RootFileProviderItem.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 11.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import FileProvider
import Foundation
import MobileCoreServices
public class RootFileProviderItem: NSObject, NSFileProviderItem {
	public var itemIdentifier = NSFileProviderItemIdentifier.rootContainer
	public let parentItemIdentifier = NSFileProviderItemIdentifier.rootContainer
	public let filename = "Home"
	public let typeIdentifier = kUTTypeFolder as String
	public let documentSize: NSNumber? = nil
	public let capabilities: NSFileProviderItemCapabilities = [.allowsAll]
}
