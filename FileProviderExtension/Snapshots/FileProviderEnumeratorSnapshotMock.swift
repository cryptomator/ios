//
//  FileProviderEnumeratorSnapshotMock.swift
//  FileProviderExtension
//
//  Created by Philipp Schmid on 14.12.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

#if SNAPSHOTS
import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import CryptomatorFileProvider
import FileProvider
import Foundation
import MobileCoreServices

public class FileProviderEnumeratorSnapshotMock: NSObject, NSFileProviderEnumerator {
	static var isUnlocked = false
	private lazy var items: [FileProviderItemSnapshotMock] = [
		.init(path: CloudPath(LocalizedString.getValue("snapshots.fileprovider.file1")), itemType: .file, contentModificationDate: currentDate - 604_800, documentSize: 254_076),
		.init(path: CloudPath("/CeBIT Award 2016.jpg"), itemType: .file, contentModificationDate: currentDate - 31_536_000, documentSize: 240_660),
		.init(path: CloudPath(LocalizedString.getValue("snapshots.fileprovider.folder1")), itemType: .folder, contentModificationDate: nil, documentSize: nil),
		.init(path: CloudPath("/Cryptomator.jpg"), itemType: .file, contentModificationDate: currentDate - 120, documentSize: 200_195),
		.init(path: CloudPath(LocalizedString.getValue("snapshots.fileprovider.file2")), itemType: .file, contentModificationDate: currentDate - 345_600, documentSize: 3_026_152),
		.init(path: CloudPath(LocalizedString.getValue("snapshots.fileprovider.folder2")), itemType: .folder, contentModificationDate: nil, documentSize: nil),
		.init(path: CloudPath(LocalizedString.getValue("snapshots.fileprovider.file3")), itemType: .file, contentModificationDate: currentDate - 604_800, documentSize: 135_137_445),
		.init(path: CloudPath(LocalizedString.getValue("snapshots.fileprovider.file4")), itemType: .file, contentModificationDate: currentDate - 518_400, documentSize: 471_027),
		.init(path: CloudPath(LocalizedString.getValue("snapshots.fileprovider.file5")), itemType: .file, contentModificationDate: currentDate - 172_800, documentSize: 1_540_417)
	]
	private lazy var currentDate = Date()
	public func invalidate() {}

	public func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
		if FileProviderEnumeratorSnapshotMock.isUnlocked {
			observer.didEnumerate(items)
			observer.finishEnumerating(upTo: nil)
		} else {
			let vaultPath = CloudPath(LocalizedString.getValue("snapshots.main.vault1"))
			let error = ErrorWrapper.wrapError(UnlockMonitorError.defaultLock, domain: NSFileProviderDomain(vaultUID: "12345", displayName: vaultPath.lastPathComponent))
			observer.finishEnumeratingWithError(error)
		}
	}
}

class FileProviderItemSnapshotMock: NSObject, NSFileProviderItem {
	var itemIdentifier: NSFileProviderItemIdentifier {
		return NSFileProviderItemIdentifier(rawValue: filename)
	}

	var parentItemIdentifier: NSFileProviderItemIdentifier = .rootContainer
	var filename: String {
		path.lastPathComponent
	}

	var contentModificationDate: Date?
	var documentSize: NSNumber?
	var typeIdentifier: String {
		switch itemType {
		case .folder:
			return kUTTypeFolder as String
		default:
			if let typeIdentifier = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, path.pathExtension as CFString, nil) {
				return typeIdentifier.takeRetainedValue() as String
			} else {
				return kUTTypeData as String
			}
		}
	}

	private let path: CloudPath
	private let itemType: CloudItemType

	init(path: CloudPath, itemType: CloudItemType, contentModificationDate: Date?, documentSize: NSNumber?) {
		self.path = path
		self.itemType = itemType
		self.contentModificationDate = contentModificationDate
		self.documentSize = documentSize
	}
}
#endif
