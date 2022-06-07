//
//  FileProviderAdapterTypeMock.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 12.01.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorFileProvider
import FileProvider
import Foundation
import Promises

// swiftlint:disable all

final class FileProviderAdapterTypeMock: FileProviderAdapterType {
	// MARK: - lastUnlockedDate

	var lastUnlockedDate: Date {
		get { underlyingLastUnlockedDate }
		set(value) { underlyingLastUnlockedDate = value }
	}

	private var underlyingLastUnlockedDate: Date!

	// MARK: - persistentIdentifierForItem

	var persistentIdentifierForItemAtCallsCount = 0
	var persistentIdentifierForItemAtCalled: Bool {
		persistentIdentifierForItemAtCallsCount > 0
	}

	var persistentIdentifierForItemAtReceivedUrl: URL?
	var persistentIdentifierForItemAtReceivedInvocations: [URL] = []
	var persistentIdentifierForItemAtReturnValue: NSFileProviderItemIdentifier?
	var persistentIdentifierForItemAtClosure: ((URL) -> NSFileProviderItemIdentifier?)?

	func persistentIdentifierForItem(at url: URL) -> NSFileProviderItemIdentifier? {
		persistentIdentifierForItemAtCallsCount += 1
		persistentIdentifierForItemAtReceivedUrl = url
		persistentIdentifierForItemAtReceivedInvocations.append(url)
		return persistentIdentifierForItemAtClosure.map({ $0(url) }) ?? persistentIdentifierForItemAtReturnValue
	}

	// MARK: - item

	var itemForThrowableError: Error?
	var itemForCallsCount = 0
	var itemForCalled: Bool {
		itemForCallsCount > 0
	}

	var itemForReceivedIdentifier: NSFileProviderItemIdentifier?
	var itemForReceivedInvocations: [NSFileProviderItemIdentifier] = []
	var itemForReturnValue: NSFileProviderItem!
	var itemForClosure: ((NSFileProviderItemIdentifier) throws -> NSFileProviderItem)?

	func item(for identifier: NSFileProviderItemIdentifier) throws -> NSFileProviderItem {
		if let error = itemForThrowableError {
			throw error
		}
		itemForCallsCount += 1
		itemForReceivedIdentifier = identifier
		itemForReceivedInvocations.append(identifier)
		return try itemForClosure.map({ try $0(identifier) }) ?? itemForReturnValue
	}

	// MARK: - enumerateItems

	var enumerateItemsForWithPageTokenCallsCount = 0
	var enumerateItemsForWithPageTokenCalled: Bool {
		enumerateItemsForWithPageTokenCallsCount > 0
	}

	var enumerateItemsForWithPageTokenReceivedArguments: (identifier: NSFileProviderItemIdentifier, pageToken: String?)?
	var enumerateItemsForWithPageTokenReceivedInvocations: [(identifier: NSFileProviderItemIdentifier, pageToken: String?)] = []
	var enumerateItemsForWithPageTokenReturnValue: Promise<FileProviderItemList>!
	var enumerateItemsForWithPageTokenClosure: ((NSFileProviderItemIdentifier, String?) -> Promise<FileProviderItemList>)?

	func enumerateItems(for identifier: NSFileProviderItemIdentifier, withPageToken pageToken: String?) -> Promise<FileProviderItemList> {
		enumerateItemsForWithPageTokenCallsCount += 1
		enumerateItemsForWithPageTokenReceivedArguments = (identifier: identifier, pageToken: pageToken)
		enumerateItemsForWithPageTokenReceivedInvocations.append((identifier: identifier, pageToken: pageToken))
		return enumerateItemsForWithPageTokenClosure.map({ $0(identifier, pageToken) }) ?? enumerateItemsForWithPageTokenReturnValue
	}

	// MARK: - importDocument

	var importDocumentAtToParentItemIdentifierCompletionHandlerCallsCount = 0
	var importDocumentAtToParentItemIdentifierCompletionHandlerCalled: Bool {
		importDocumentAtToParentItemIdentifierCompletionHandlerCallsCount > 0
	}

	var importDocumentAtToParentItemIdentifierCompletionHandlerReceivedArguments: (fileURL: URL, parentItemIdentifier: NSFileProviderItemIdentifier, completionHandler: (NSFileProviderItem?, Error?) -> Void)?
	var importDocumentAtToParentItemIdentifierCompletionHandlerReceivedInvocations: [(fileURL: URL, parentItemIdentifier: NSFileProviderItemIdentifier, completionHandler: (NSFileProviderItem?, Error?) -> Void)] = []
	var importDocumentAtToParentItemIdentifierCompletionHandlerClosure: ((URL, NSFileProviderItemIdentifier, @escaping (NSFileProviderItem?, Error?) -> Void) -> Void)?

	func importDocument(at fileURL: URL, toParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
		importDocumentAtToParentItemIdentifierCompletionHandlerCallsCount += 1
		importDocumentAtToParentItemIdentifierCompletionHandlerReceivedArguments = (fileURL: fileURL, parentItemIdentifier: parentItemIdentifier, completionHandler: completionHandler)
		importDocumentAtToParentItemIdentifierCompletionHandlerReceivedInvocations.append((fileURL: fileURL, parentItemIdentifier: parentItemIdentifier, completionHandler: completionHandler))
		importDocumentAtToParentItemIdentifierCompletionHandlerClosure?(fileURL, parentItemIdentifier, completionHandler)
	}

	// MARK: - itemChanged

	var itemChangedAtCallsCount = 0
	var itemChangedAtCalled: Bool {
		itemChangedAtCallsCount > 0
	}

	var itemChangedAtReceivedUrl: URL?
	var itemChangedAtReceivedInvocations: [URL] = []
	var itemChangedAtClosure: ((URL) -> Void)?

	func itemChanged(at url: URL) {
		itemChangedAtCallsCount += 1
		itemChangedAtReceivedUrl = url
		itemChangedAtReceivedInvocations.append(url)
		itemChangedAtClosure?(url)
	}

	// MARK: - createDirectory

	var createDirectoryWithNameInParentItemIdentifierCompletionHandlerCallsCount = 0
	var createDirectoryWithNameInParentItemIdentifierCompletionHandlerCalled: Bool {
		createDirectoryWithNameInParentItemIdentifierCompletionHandlerCallsCount > 0
	}

	var createDirectoryWithNameInParentItemIdentifierCompletionHandlerReceivedArguments: (directoryName: String, parentItemIdentifier: NSFileProviderItemIdentifier, completionHandler: (NSFileProviderItem?, Error?) -> Void)?
	var createDirectoryWithNameInParentItemIdentifierCompletionHandlerReceivedInvocations: [(directoryName: String, parentItemIdentifier: NSFileProviderItemIdentifier, completionHandler: (NSFileProviderItem?, Error?) -> Void)] = []
	var createDirectoryWithNameInParentItemIdentifierCompletionHandlerClosure: ((String, NSFileProviderItemIdentifier, @escaping (NSFileProviderItem?, Error?) -> Void) -> Void)?

	func createDirectory(withName directoryName: String, inParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
		createDirectoryWithNameInParentItemIdentifierCompletionHandlerCallsCount += 1
		createDirectoryWithNameInParentItemIdentifierCompletionHandlerReceivedArguments = (directoryName: directoryName, parentItemIdentifier: parentItemIdentifier, completionHandler: completionHandler)
		createDirectoryWithNameInParentItemIdentifierCompletionHandlerReceivedInvocations.append((directoryName: directoryName, parentItemIdentifier: parentItemIdentifier, completionHandler: completionHandler))
		createDirectoryWithNameInParentItemIdentifierCompletionHandlerClosure?(directoryName, parentItemIdentifier, completionHandler)
	}

	// MARK: - stopProvidingItem

	var stopProvidingItemAtCallsCount = 0
	var stopProvidingItemAtCalled: Bool {
		stopProvidingItemAtCallsCount > 0
	}

	var stopProvidingItemAtReceivedUrl: URL?
	var stopProvidingItemAtReceivedInvocations: [URL] = []
	var stopProvidingItemAtClosure: ((URL) -> Void)?

	func stopProvidingItem(at url: URL) {
		stopProvidingItemAtCallsCount += 1
		stopProvidingItemAtReceivedUrl = url
		stopProvidingItemAtReceivedInvocations.append(url)
		stopProvidingItemAtClosure?(url)
	}

	// MARK: - renameItem

	var renameItemWithIdentifierToNameCompletionHandlerCallsCount = 0
	var renameItemWithIdentifierToNameCompletionHandlerCalled: Bool {
		renameItemWithIdentifierToNameCompletionHandlerCallsCount > 0
	}

	var renameItemWithIdentifierToNameCompletionHandlerReceivedArguments: (itemIdentifier: NSFileProviderItemIdentifier, itemName: String, completionHandler: (NSFileProviderItem?, Error?) -> Void)?
	var renameItemWithIdentifierToNameCompletionHandlerReceivedInvocations: [(itemIdentifier: NSFileProviderItemIdentifier, itemName: String, completionHandler: (NSFileProviderItem?, Error?) -> Void)] = []
	var renameItemWithIdentifierToNameCompletionHandlerClosure: ((NSFileProviderItemIdentifier, String, @escaping (NSFileProviderItem?, Error?) -> Void) -> Void)?

	func renameItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, toName itemName: String, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
		renameItemWithIdentifierToNameCompletionHandlerCallsCount += 1
		renameItemWithIdentifierToNameCompletionHandlerReceivedArguments = (itemIdentifier: itemIdentifier, itemName: itemName, completionHandler: completionHandler)
		renameItemWithIdentifierToNameCompletionHandlerReceivedInvocations.append((itemIdentifier: itemIdentifier, itemName: itemName, completionHandler: completionHandler))
		renameItemWithIdentifierToNameCompletionHandlerClosure?(itemIdentifier, itemName, completionHandler)
	}

	// MARK: - reparentItem

	var reparentItemWithIdentifierToParentItemWithIdentifierNewNameCompletionHandlerCallsCount = 0
	var reparentItemWithIdentifierToParentItemWithIdentifierNewNameCompletionHandlerCalled: Bool {
		reparentItemWithIdentifierToParentItemWithIdentifierNewNameCompletionHandlerCallsCount > 0
	}

	var reparentItemWithIdentifierToParentItemWithIdentifierNewNameCompletionHandlerReceivedArguments: (itemIdentifier: NSFileProviderItemIdentifier, parentItemIdentifier: NSFileProviderItemIdentifier, newName: String?, completionHandler: (NSFileProviderItem?, Error?) -> Void)?
	var reparentItemWithIdentifierToParentItemWithIdentifierNewNameCompletionHandlerReceivedInvocations: [(itemIdentifier: NSFileProviderItemIdentifier, parentItemIdentifier: NSFileProviderItemIdentifier, newName: String?, completionHandler: (NSFileProviderItem?, Error?) -> Void)] = []
	var reparentItemWithIdentifierToParentItemWithIdentifierNewNameCompletionHandlerClosure: ((NSFileProviderItemIdentifier, NSFileProviderItemIdentifier, String?, @escaping (NSFileProviderItem?, Error?) -> Void) -> Void)?

	func reparentItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, toParentItemWithIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, newName: String?, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
		reparentItemWithIdentifierToParentItemWithIdentifierNewNameCompletionHandlerCallsCount += 1
		reparentItemWithIdentifierToParentItemWithIdentifierNewNameCompletionHandlerReceivedArguments = (itemIdentifier: itemIdentifier, parentItemIdentifier: parentItemIdentifier, newName: newName, completionHandler: completionHandler)
		reparentItemWithIdentifierToParentItemWithIdentifierNewNameCompletionHandlerReceivedInvocations.append((itemIdentifier: itemIdentifier, parentItemIdentifier: parentItemIdentifier, newName: newName, completionHandler: completionHandler))
		reparentItemWithIdentifierToParentItemWithIdentifierNewNameCompletionHandlerClosure?(itemIdentifier, parentItemIdentifier, newName, completionHandler)
	}

	// MARK: - deleteItem

	var deleteItemWithIdentifierCompletionHandlerCallsCount = 0
	var deleteItemWithIdentifierCompletionHandlerCalled: Bool {
		deleteItemWithIdentifierCompletionHandlerCallsCount > 0
	}

	var deleteItemWithIdentifierCompletionHandlerReceivedArguments: (itemIdentifier: NSFileProviderItemIdentifier, completionHandler: (Error?) -> Void)?
	var deleteItemWithIdentifierCompletionHandlerReceivedInvocations: [(itemIdentifier: NSFileProviderItemIdentifier, completionHandler: (Error?) -> Void)] = []
	var deleteItemWithIdentifierCompletionHandlerClosure: ((NSFileProviderItemIdentifier, @escaping (Error?) -> Void) -> Void)?

	func deleteItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (Error?) -> Void) {
		deleteItemWithIdentifierCompletionHandlerCallsCount += 1
		deleteItemWithIdentifierCompletionHandlerReceivedArguments = (itemIdentifier: itemIdentifier, completionHandler: completionHandler)
		deleteItemWithIdentifierCompletionHandlerReceivedInvocations.append((itemIdentifier: itemIdentifier, completionHandler: completionHandler))
		deleteItemWithIdentifierCompletionHandlerClosure?(itemIdentifier, completionHandler)
	}

	// MARK: - startProvidingItem

	var startProvidingItemAtCompletionHandlerCallsCount = 0
	var startProvidingItemAtCompletionHandlerCalled: Bool {
		startProvidingItemAtCompletionHandlerCallsCount > 0
	}

	var startProvidingItemAtCompletionHandlerReceivedArguments: (url: URL, completionHandler: (_ error: Error?) -> Void)?
	var startProvidingItemAtCompletionHandlerReceivedInvocations: [(url: URL, completionHandler: (_ error: Error?) -> Void)] = []
	var startProvidingItemAtCompletionHandlerClosure: ((URL, @escaping (_ error: Error?) -> Void) -> Void)?

	func startProvidingItem(at url: URL, completionHandler: @escaping (_ error: Error?) -> Void) {
		startProvidingItemAtCompletionHandlerCallsCount += 1
		startProvidingItemAtCompletionHandlerReceivedArguments = (url: url, completionHandler: completionHandler)
		startProvidingItemAtCompletionHandlerReceivedInvocations.append((url: url, completionHandler: completionHandler))
		startProvidingItemAtCompletionHandlerClosure?(url, completionHandler)
	}

	// MARK: - setFavoriteRank

	var setFavoriteRankForItemIdentifierCompletionHandlerCallsCount = 0
	var setFavoriteRankForItemIdentifierCompletionHandlerCalled: Bool {
		setFavoriteRankForItemIdentifierCompletionHandlerCallsCount > 0
	}

	var setFavoriteRankForItemIdentifierCompletionHandlerReceivedArguments: (favoriteRank: NSNumber?, itemIdentifier: NSFileProviderItemIdentifier, completionHandler: (NSFileProviderItem?, Error?) -> Void)?
	var setFavoriteRankForItemIdentifierCompletionHandlerReceivedInvocations: [(favoriteRank: NSNumber?, itemIdentifier: NSFileProviderItemIdentifier, completionHandler: (NSFileProviderItem?, Error?) -> Void)] = []
	var setFavoriteRankForItemIdentifierCompletionHandlerClosure: ((NSNumber?, NSFileProviderItemIdentifier, @escaping (NSFileProviderItem?, Error?) -> Void) -> Void)?

	func setFavoriteRank(_ favoriteRank: NSNumber?, forItemIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
		setFavoriteRankForItemIdentifierCompletionHandlerCallsCount += 1
		setFavoriteRankForItemIdentifierCompletionHandlerReceivedArguments = (favoriteRank: favoriteRank, itemIdentifier: itemIdentifier, completionHandler: completionHandler)
		setFavoriteRankForItemIdentifierCompletionHandlerReceivedInvocations.append((favoriteRank: favoriteRank, itemIdentifier: itemIdentifier, completionHandler: completionHandler))
		setFavoriteRankForItemIdentifierCompletionHandlerClosure?(favoriteRank, itemIdentifier, completionHandler)
	}

	// MARK: - setTagData

	var setTagDataForItemIdentifierCompletionHandlerCallsCount = 0
	var setTagDataForItemIdentifierCompletionHandlerCalled: Bool {
		setTagDataForItemIdentifierCompletionHandlerCallsCount > 0
	}

	var setTagDataForItemIdentifierCompletionHandlerReceivedArguments: (tagData: Data?, itemIdentifier: NSFileProviderItemIdentifier, completionHandler: (NSFileProviderItem?, Error?) -> Void)?
	var setTagDataForItemIdentifierCompletionHandlerReceivedInvocations: [(tagData: Data?, itemIdentifier: NSFileProviderItemIdentifier, completionHandler: (NSFileProviderItem?, Error?) -> Void)] = []
	var setTagDataForItemIdentifierCompletionHandlerClosure: ((Data?, NSFileProviderItemIdentifier, @escaping (NSFileProviderItem?, Error?) -> Void) -> Void)?

	func setTagData(_ tagData: Data?, forItemIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
		setTagDataForItemIdentifierCompletionHandlerCallsCount += 1
		setTagDataForItemIdentifierCompletionHandlerReceivedArguments = (tagData: tagData, itemIdentifier: itemIdentifier, completionHandler: completionHandler)
		setTagDataForItemIdentifierCompletionHandlerReceivedInvocations.append((tagData: tagData, itemIdentifier: itemIdentifier, completionHandler: completionHandler))
		setTagDataForItemIdentifierCompletionHandlerClosure?(tagData, itemIdentifier, completionHandler)
	}

	// MARK: - retryUpload

	var retryUploadForCallsCount = 0
	var retryUploadForCalled: Bool {
		retryUploadForCallsCount > 0
	}

	var retryUploadForReceivedItemIdentifier: NSFileProviderItemIdentifier?
	var retryUploadForReceivedInvocations: [NSFileProviderItemIdentifier] = []
	var retryUploadForClosure: ((NSFileProviderItemIdentifier) -> Void)?

	func retryUpload(for itemIdentifier: NSFileProviderItemIdentifier) {
		retryUploadForCallsCount += 1
		retryUploadForReceivedItemIdentifier = itemIdentifier
		retryUploadForReceivedInvocations.append(itemIdentifier)
		retryUploadForClosure?(itemIdentifier)
	}

	// MARK: - getItemIdentifier

	var getItemIdentifierForCallsCount = 0
	var getItemIdentifierForCalled: Bool {
		getItemIdentifierForCallsCount > 0
	}

	var getItemIdentifierForReceivedArguments: CloudPath?
	var getItemIdentifierForReceivedInvocations: [CloudPath] = []
	var getItemIdentifierForReturnValue: Promise<NSFileProviderItemIdentifier>!
	var getItemIdentifierForClosure: ((CloudPath) -> Promise<NSFileProviderItemIdentifier>)?

	func getItemIdentifier(for cloudPath: CloudPath) -> Promise<NSFileProviderItemIdentifier> {
		getItemIdentifierForCallsCount += 1
		getItemIdentifierForReceivedArguments = cloudPath
		getItemIdentifierForReceivedInvocations.append(cloudPath)
		return getItemIdentifierForClosure.map({ $0(cloudPath) }) ?? getItemIdentifierForReturnValue
	}
}

// swiftlint:enable all
