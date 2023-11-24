//
//  FileProviderItem.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 25.06.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import Dependencies
import FileProvider
import Foundation
import MobileCoreServices

public class FileProviderItem: NSObject, NSFileProviderItem {
	static let readOnlyCapabilities: NSFileProviderItemCapabilities = .allowsReading

	// TODO: implement an initializer to create an item from your extension's backing model
	// TODO: implement the accessors to return the values from your extension's backing model
	let metadata: ItemMetadata
	let error: Error?
	let newestVersionLocallyCached: Bool
	let localURL: URL?
	let domainIdentifier: NSFileProviderDomainIdentifier
	@Dependency(\.fullVersionChecker) private var fullVersionChecker
	@Dependency(\.permissionProvider) private var permissionProvider

	init(metadata: ItemMetadata, domainIdentifier: NSFileProviderDomainIdentifier, newestVersionLocallyCached: Bool = false, localURL: URL? = nil, error: Error? = nil) {
		self.metadata = metadata
		self.domainIdentifier = domainIdentifier
		self.error = error
		self.newestVersionLocallyCached = newestVersionLocallyCached
		self.localURL = localURL
	}

	public var itemIdentifier: NSFileProviderItemIdentifier {
		assert(metadata.id != nil)

		guard let id = metadata.id, id != NSFileProviderItemIdentifier.rootContainerDatabaseValue else {
			return .rootContainer
		}
		return NSFileProviderItemIdentifier(domainIdentifier: domainIdentifier, itemID: id)
	}

	public var parentItemIdentifier: NSFileProviderItemIdentifier {
		if metadata.parentID == NSFileProviderItemIdentifier.rootContainerDatabaseValue {
			return .rootContainer
		}
		return NSFileProviderItemIdentifier(domainIdentifier: domainIdentifier, itemID: metadata.parentID)
	}

	public var capabilities: NSFileProviderItemCapabilities {
		return permissionProvider.getPermissions(for: metadata, at: domainIdentifier)
	}

	public var filename: String {
		return metadata.name
	}

	public var typeIdentifier: String {
		switch metadata.type {
		case .folder:
			return kUTTypeFolder as String
		default:
			if let typeIdentifier = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, metadata.cloudPath.pathExtension as CFString, nil) {
				let uti = typeIdentifier.takeRetainedValue() as String
				// Reject dynamic created UTI and use generic UTI (kUTTypeData) instead. See: https://github.com/cryptomator/ios/issues/67#issuecomment-898371262
				if uti.hasPrefix("dyn.") {
					return kUTTypeData as String
				} else {
					return uti
				}
			} else {
				return kUTTypeData as String
			}
		}
	}

	public var documentSize: NSNumber? {
		return metadata.size as NSNumber?
	}

	public var isDownloaded: Bool {
		if metadata.type == .folder {
			// Needs to return true for folders in order to allow browsing while offline
			// Otherwise Files app will bring up an alert "You're not connected to the Internet"
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

	public var favoriteRank: NSNumber? {
		return metadata.favoriteRank as NSNumber?
	}

	public var tagData: Data? {
		return metadata.tagData
	}

	/**
	 Dictionary to add state information to the item. Entries are accessible to
	 user interaction predicates via the `Info.plist` of the FileProviderExtensionUI

	 Used to enable the customized FileProviderExtensionUI actions.
	 */
	public var userInfo: [AnyHashable: Any]? {
		let isFolder = typeIdentifier == kUTTypeFolder as String
		return ["enableRetryWaitingUploadAction": uploadingError == nil && isUploading && !isFolder,
		        "enableRetryFailedUploadAction": uploadingError != nil,
		        "enableEvictFileFromCacheAction": !isUploading && !isDownloading && isDownloaded && !isFolder]
	}
}
