//
//  FileProviderItem.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 25.06.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import FileProvider
import Foundation
public class FileProviderItem: NSObject, NSFileProviderItem {
	// TODO: implement an initializer to create an item from your extension's backing model
	// TODO: implement the accessors to return the values from your extension's backing model
	private let metadata: ItemMetadata

	init(metadata: ItemMetadata) {
		self.metadata = metadata
	}

	public var itemIdentifier: NSFileProviderItemIdentifier {

		assert(metadata.id != nil)
		return NSFileProviderItemIdentifier(String(metadata.id ?? -1)) //TODO: Change Optional Handling
	}

	public var parentItemIdentifier: NSFileProviderItemIdentifier {
		return NSFileProviderItemIdentifier(String(metadata.parentId))
	}

	public var capabilities: NSFileProviderItemCapabilities {
		return .allowsAll
	}

	public var filename: String {
		return metadata.name
	}

	public var typeIdentifier: String {
		// TODO: Change this to real types
		switch metadata.type {
		case .folder:
			return "public.folder"
		default:
			return "public.image"
		}
	}

	public var documentSize: NSNumber? {
		return metadata.size as NSNumber?
	}
}
