//
//  FileProviderItem.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 25.06.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import FileProvider
import Foundation
import MobileCoreServices
public class FileProviderItem: NSObject, NSFileProviderItem {
	// TODO: implement an initializer to create an item from your extension's backing model
	// TODO: implement the accessors to return the values from your extension's backing model
	let metadata: ItemMetadata
	let error: Error?
	let newestVersionLocallyCached: Bool
	let localURL: URL?

	init(metadata: ItemMetadata, newestVersionLocallyCached: Bool = false, localURL: URL? = nil, error: Error? = nil) {
		self.metadata = metadata
		self.error = error
		self.newestVersionLocallyCached = newestVersionLocallyCached
		self.localURL = localURL
	}

	public var itemIdentifier: NSFileProviderItemIdentifier {
		assert(metadata.id != nil)
		if metadata.id == MetadataManager.rootContainerId {
			return .rootContainer
		}
		return NSFileProviderItemIdentifier(String(metadata.id ?? -1)) // TODO: Change Optional Handling
	}

	public var parentItemIdentifier: NSFileProviderItemIdentifier {
		if metadata.parentId == MetadataManager.rootContainerId {
			return .rootContainer
		}
		return NSFileProviderItemIdentifier(String(metadata.parentId))
	}

	public var capabilities: NSFileProviderItemCapabilities {
		if metadata.statusCode == .uploadError {
			return .allowsDeleting
		}
		if metadata.type == .folder {
			return [.allowsAddingSubItems, .allowsContentEnumerating, .allowsReading, .allowsDeleting, .allowsRenaming, .allowsReparenting]
		}
		if metadata.statusCode == .isUploading {
			return .allowsReading
		}
		return [.allowsWriting, .allowsReading, .allowsDeleting, .allowsRenaming, .allowsReparenting]
	}

	public var filename: String {
		return metadata.name
	}

	public var typeIdentifier: String {
		switch metadata.type {
		case .folder:
			return "public.folder"
		default:
			if let typeIdentifier = UTTypeCreatePreferredIdentifierForTag(
				kUTTagClassFilenameExtension,
				metadata.cloudPath.pathExtension as CFString,
				nil
			) {
				return typeIdentifier.takeRetainedValue() as String
			} else {
				return "public.file"
			}
		}
	}

	public var documentSize: NSNumber? {
		return metadata.size as NSNumber?
	}

	public var isDownloaded: Bool {
		if metadata.type == .folder {
			// Needs to return true for folders in order to allow browsing while offline
			// Otherwise Files.app will bring up an alert "You're not connected to the Internet"
			return true
		}
		guard let localURL = localURL else {
			return false
		}
		return FileManager.default.fileExists(atPath: localURL.path)
	}

	public var isDownloading: Bool {
		return metadata.statusCode == .isDownloading
	}

	public var isUploading: Bool {
		return metadata.statusCode == .isUploading
	}

	public var isUploaded: Bool {
		if metadata.statusCode == .uploadError || metadata.isPlaceholderItem {
			return false
		}
		return metadata.statusCode != .isUploading
	}

	public var contentModificationDate: Date? {
		return metadata.lastModifiedDate
	}

	public var isTrashed: Bool {
		return false
	}

	public var childItemCount: NSNumber? {
		return nil
	}

	public var isMostRecentVersionDownloaded: Bool {
		return newestVersionLocallyCached
	}

	public var uploadingError: Error? {
		if metadata.statusCode != .uploadError {
			return nil
		}
		return error
	}

	public var downloadingError: Error? {
		if metadata.statusCode != .downloadError {
			return nil
		}
		return error
	}
}
