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
import MobileCoreServices
public class FileProviderItem: NSObject, NSFileProviderItem {
	// TODO: implement an initializer to create an item from your extension's backing model
	// TODO: implement the accessors to return the values from your extension's backing model
	let metadata: ItemMetadata
	let uploadTask: UploadTask?

	init(metadata: ItemMetadata, uploadTask: UploadTask? = nil) {
		self.metadata = metadata
		self.uploadTask = uploadTask
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
		if metadata.statusCode == .isUploading {
			return .allowsReading
		}
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
			let remoteURL = URL(fileURLWithPath: metadata.remotePath, isDirectory: false)
			if let typeIdentifier = UTTypeCreatePreferredIdentifierForTag(
				kUTTagClassFilenameExtension,
				remoteURL.pathExtension as CFString,
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
		return metadata.statusCode == .isDownloaded
	}

	public var isDownloading: Bool {
		return metadata.statusCode == .isDownloading
	}

	public var isUploading: Bool {
		return metadata.statusCode == .isUploading
	}

	public var isUploaded: Bool {
		if metadata.statusCode == .uploadError {
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
		return true
	}

	public var uploadingError: Error? {
		if let errorCode = uploadTask?.uploadErrorCode, let errorDomain = uploadTask?.uploadErrorDomain {
			switch errorDomain {
			case NSFileProviderErrorDomain:
				if let fileProviderErrorCode = NSFileProviderError.Code(rawValue: errorCode) {
					return NSFileProviderError(fileProviderErrorCode)
				}
				return NSError(domain: errorDomain, code: errorCode, userInfo: nil)
			case NSCocoaErrorDomain:
				return CocoaError(CocoaError.Code(rawValue: errorCode))
			default:
				return NSError(domain: errorDomain, code: errorCode, userInfo: nil)
			}
		} else {
			return nil
		}
	}
}
