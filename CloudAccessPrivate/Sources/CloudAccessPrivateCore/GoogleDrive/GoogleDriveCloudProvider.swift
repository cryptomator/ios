//
//  GoogleDriveCloudProvider.swift
//  CloudAccessPrivate-Core
//
//  Created by Philipp Schmid on 24.04.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import Foundation
import GoogleAPIClientForREST_Drive
import GRDB
import GTMSessionFetcherCore
import Promises

public class GoogleDriveCloudProvider: CloudProvider {
	static let maximumUploadFetcherChunkSize: UInt = 3 * 1024 * 1024 // 3MB per chunk as GTMSessionFetcher loads the chunk to the memory and the FileProviderExtension has a total memory limit of 15mb
	private let credentials: GoogleDriveCredential
	private let cloudIdentifierCache: GoogleDriveCloudIdentifierCacheManager?
	private var runningTickets: [GTLRServiceTicket]
	private var runningFetchers: [GTMSessionFetcher]

	public init(with credentials: GoogleDriveCredential) {
		self.credentials = credentials
		self.runningTickets = [GTLRServiceTicket]()
		self.runningFetchers = [GTMSessionFetcher]()
		self.cloudIdentifierCache = GoogleDriveCloudIdentifierCacheManager()
	}

	deinit {
		for ticket in runningTickets {
			ticket.cancel()
		}
		for fetcher in runningFetchers {
			fetcher.stopFetching()
		}
	}

	public func fetchItemMetadata(at cloudPath: CloudPath) -> Promise<CloudItemMetadata> {
		return resolvePath(forItemAt: cloudPath).then { identifier in
			self.fetchItemMetadata(forItemIdentifier: identifier, at: cloudPath)
		}
	}

	public func fetchItemList(forFolderAt cloudPath: CloudPath, withPageToken pageToken: String?) -> Promise<CloudItemList> {
		return resolvePath(forFolderAt: cloudPath).then { identifier in
			self.fetchGTLRDriveFileList(forFolderAt: cloudPath, withIdentifier: identifier, withPageToken: pageToken)
		}.then { fileList in
			let cloudItemList = try self.convertGTLRDriveFileListToCloudItemList(fileList, forFolderAt: cloudPath)
			return Promise(cloudItemList)
		}
	}

	public func downloadFile(from cloudPath: CloudPath, to localURL: URL) -> Promise<Void> {
		precondition(localURL.isFileURL)
		precondition(!localURL.hasDirectoryPath)
		if FileManager.default.fileExists(atPath: localURL.path) {
			return Promise(CloudProviderError.itemAlreadyExists)
		}
		let progress = Progress(totalUnitCount: 1)
		return resolvePath(forFileAt: cloudPath).then { identifier -> Promise<Void> in
			progress.becomeCurrent(withPendingUnitCount: 1)
			let downloadPromise = self.downloadFile(withIdentifier: identifier, from: cloudPath, to: localURL)
			progress.resignCurrent()
			return downloadPromise
		}
	}

	public func uploadFile(from localURL: URL, to cloudPath: CloudPath, replaceExisting: Bool) -> Promise<CloudItemMetadata> {
		precondition(localURL.isFileURL)
		precondition(!localURL.hasDirectoryPath)
		var isDirectory: ObjCBool = false
		let fileExists = FileManager.default.fileExists(atPath: localURL.path, isDirectory: &isDirectory)
		if !fileExists {
			return Promise(CloudProviderError.itemNotFound)
		}
		if isDirectory.boolValue {
			return Promise(CloudProviderError.itemTypeMismatch)
		}
		let progress = Progress(totalUnitCount: -1)
		return resolveParentPath(for: cloudPath).then { parentIdentfier in
			self.createFileUploadQuery(from: localURL, to: cloudPath, parentIdentifier: parentIdentfier, replaceExisting: replaceExisting)
		}.then { query -> Promise<Any> in
			query.executionParameters.uploadProgressBlock = { _, totalBytesUploaded, totalBytesExpectedToUpload in
				progress.totalUnitCount = Int64(totalBytesExpectedToUpload)
				progress.completedUnitCount = Int64(totalBytesUploaded)
			}
			query.fields = "id, name, modifiedTime, mimeType"
			return self.executeQuery(query)
		}.then { result -> CloudItemMetadata in
			if let uploadedFile = result as? GTLRDrive_File {
				guard let identifier = uploadedFile.identifier, let name = uploadedFile.name, let lastModifiedDate = uploadedFile.modifiedTime?.date, let mimeType = uploadedFile.mimeType else {
					throw GoogleDriveError.receivedIncompleteMetadata
				}
				try self.cloudIdentifierCache?.cacheIdentifier(identifier, for: cloudPath)
				let itemType = self.getCloudItemType(forMimeType: mimeType)
				let metadata = CloudItemMetadata(name: name, cloudPath: cloudPath, itemType: itemType, lastModifiedDate: lastModifiedDate, size: uploadedFile.size?.intValue)
				return metadata
			} else {
				throw GoogleDriveError.unexpectedResultType
			}
		}
	}

	public func createFolder(at cloudPath: CloudPath) -> Promise<Void> {
		let foldername = cloudPath.lastPathComponent
		return Promise<Void>(on: .global()) { fulfill, reject in
			let parentIdentifier = try await (self.resolveParentPath(for: cloudPath))
			do {
				_ = try await (self.getFirstIdentifier(forItemWithName: foldername, itemType: .folder, inFolderWithId: parentIdentifier))
				reject(CloudProviderError.itemAlreadyExists)
			} catch CloudProviderError.itemNotFound {
				_ = try await (self.createFolder(at: cloudPath, withParentIdentifier: parentIdentifier))
				fulfill(())
			} catch CloudProviderError.itemTypeMismatch {
				reject(CloudProviderError.itemAlreadyExists)
			}
		}
	}

	public func deleteFile(at cloudPath: CloudPath) -> Promise<Void> {
		return resolvePath(forFileAt: cloudPath).then { identifier in
			self.deleteItem(withIdentifier: identifier, at: cloudPath)
		}
	}

	public func deleteFolder(at cloudPath: CloudPath) -> Promise<Void> {
		return resolvePath(forFolderAt: cloudPath).then { identifier in
			self.deleteItem(withIdentifier: identifier, at: cloudPath)
		}
	}

	public func moveFile(from sourceCloudPath: CloudPath, to targetCloudPath: CloudPath) -> Promise<Void> {
		return resolveParentPath(for: targetCloudPath).then { _ in
			self.checkForItemExistence(at: targetCloudPath)
		}.then { itemExists -> Void in
			if itemExists {
				throw CloudProviderError.itemAlreadyExists
			}
		}.then {
			self.resolvePath(forFileAt: sourceCloudPath)
		}.then { fileIdentifier in
			self.moveItem(from: sourceCloudPath, to: targetCloudPath, withItemIdentifier: fileIdentifier)
		}
	}

	public func moveFolder(from sourceCloudPath: CloudPath, to targetCloudPath: CloudPath) -> Promise<Void> {
		return resolveParentPath(for: targetCloudPath).then { _ in
			self.checkForItemExistence(at: targetCloudPath)
		}.then { itemExists -> Void in
			if itemExists {
				throw CloudProviderError.itemAlreadyExists
			}
		}.then {
			self.resolvePath(forFolderAt: sourceCloudPath)
		}.then { fileIdentifier in
			self.moveItem(from: sourceCloudPath, to: targetCloudPath, withItemIdentifier: fileIdentifier)
		}
	}

	private func moveItem(from sourceCloudPath: CloudPath, to targetCloudPath: CloudPath, withItemIdentifier itemIdentifier: String) -> Promise<Void> {
		let metadata = GTLRDrive_File()
		metadata.name = targetCloudPath.lastPathComponent
		let query = GTLRDriveQuery_FilesUpdate.query(withObject: metadata, fileId: itemIdentifier, uploadParameters: nil)
		return modificateQueryForMoveItem(query, from: sourceCloudPath, to: targetCloudPath)
			.then { query in
				self.executeQuery(query, cloudPath: sourceCloudPath)
			}.then { result -> Void in
				guard let file = result as? GTLRDrive_File else {
					throw GoogleDriveError.unexpectedResultType
				}
				guard let identifier = file.identifier else {
					throw GoogleDriveError.receivedIncompleteMetadata
				}
				try self.cloudIdentifierCache?.uncacheIdentifier(for: sourceCloudPath)
				try self.cloudIdentifierCache?.cacheIdentifier(identifier, for: targetCloudPath)
				return
			}
	}

	private func modificateQueryForMoveItem(_ query: GTLRDriveQuery_FilesUpdate, from sourceCloudPath: CloudPath, to targetCloudPath: CloudPath) -> Promise<GTLRDriveQuery_FilesUpdate> {
		query.fields = "id, modifiedTime"
		if !onlyItemNameChangedBetween(sourceCloudPath, and: targetCloudPath) {
			let sourceParentCloudPath = sourceCloudPath.deletingLastPathComponent()
			let targetParentCloudPath = targetCloudPath.deletingLastPathComponent()
			return all(resolvePath(forFolderAt: sourceParentCloudPath), resolvePath(forFolderAt: targetParentCloudPath)).then { oldParentIdentifier, newParentIdentifier -> GTLRDriveQuery_FilesUpdate in
				query.addParents = newParentIdentifier
				query.removeParents = oldParentIdentifier
				return query
			}
		}
		return Promise(query)
	}

	func resolvePath(forItemAt cloudPath: CloudPath) -> Promise<String> {
		var pathToCheckForCache = cloudPath
		var cachedIdentifier = cloudIdentifierCache?.getIdentifier(for: pathToCheckForCache)
		while cachedIdentifier == nil, !pathToCheckForCache.pathComponents.isEmpty {
			pathToCheckForCache = pathToCheckForCache.deletingLastPathComponent()
			cachedIdentifier = cloudIdentifierCache?.getIdentifier(for: pathToCheckForCache)
		}
		if pathToCheckForCache != cloudPath {
			let parentFolderPath = cloudPath.deletingLastPathComponent()
			let itemName = cloudPath.lastPathComponent
			if pathToCheckForCache != parentFolderPath {
				return traverseThroughPathToFolder(from: pathToCheckForCache, to: parentFolderPath, withStartIdentifier: cachedIdentifier!).then { parentIdentifier in
					self.getFirstIdentifier(forItemWithName: itemName, itemType: nil, inFolderWithId: parentIdentifier)
				}.then { itemIdentifier in
					try self.cloudIdentifierCache?.cacheIdentifier(itemIdentifier, for: cloudPath)
				}
			}
			return getFirstIdentifier(forItemWithName: itemName, itemType: nil, inFolderWithId: cachedIdentifier!)
				.then { itemIdentifier in
					try self.cloudIdentifierCache?.cacheIdentifier(itemIdentifier, for: cloudPath)
				}
		}
		return Promise(cachedIdentifier!)
	}

	/**
	 Resolve cloudPath to Google Drive Item Identifier
	 - Returns: ItemIdentifier on Google Drive, which belongs to the Folder to which the cloudPath points
	 */
	func resolvePath(forFolderAt cloudPath: CloudPath) -> Promise<String> {
		var urlToCheckForCache = cloudPath
		var cachedIdentifier = cloudIdentifierCache?.getIdentifier(for: urlToCheckForCache)
		while cachedIdentifier == nil, !urlToCheckForCache.pathComponents.isEmpty {
			urlToCheckForCache = urlToCheckForCache.deletingLastPathComponent()
			cachedIdentifier = cloudIdentifierCache?.getIdentifier(for: urlToCheckForCache)
		}
		if urlToCheckForCache != cloudPath {
			return traverseThroughPathToFolder(from: urlToCheckForCache, to: cloudPath, withStartIdentifier: cachedIdentifier!)
		}
		return Promise(cachedIdentifier!)
	}

	/**
	 Resolve cloudPath to Google Drive Item Identifier
	 - Returns: ItemIdentifier on Google Drive, which belongs to the File to which the remoteURL points
	 */
	func resolvePath(forFileAt cloudPath: CloudPath) -> Promise<String> {
		var urlToCheckForCache = cloudPath
		var cachedIdentifier = cloudIdentifierCache?.getIdentifier(for: urlToCheckForCache)
		while cachedIdentifier == nil, !urlToCheckForCache.pathComponents.isEmpty {
			urlToCheckForCache = urlToCheckForCache.deletingLastPathComponent()
			cachedIdentifier = cloudIdentifierCache?.getIdentifier(for: urlToCheckForCache)
		}
		if urlToCheckForCache != cloudPath {
			return traverseThroughPathToFile(from: urlToCheckForCache, to: cloudPath, withStartIdentifier: cachedIdentifier!)
		}
		return Promise(cachedIdentifier!)
	}

	/**
	 Searches the folder belonging to `inFolderWithId` for an item with the same name as `itemName`.
	 This is necessary because Google Drive does not use normal paths, but only works with (parent-)identifiers.
	 If an `itemType` is passed, only items with the respective type (folder / file) will be considered.
	 workaround for cyrillic names: https://stackoverflow.com/a/47282129/1759462
	 */
	private func getFirstIdentifier(forItemWithName itemName: String, itemType: CloudItemType?, inFolderWithId: String) -> Promise<String> {
		let query = GTLRDriveQuery_FilesList.query()
		query.q = "'\(inFolderWithId)' in parents and name contains '\(itemName)' and trashed = false"
		query.fields = "files(id, name, mimeType)"
		var hasFoundItemWithWrongType = false
		return executeQuery(query).then { result -> String in
			if let fileList = result as? GTLRDrive_FileList {
				for file in fileList.files ?? [GTLRDrive_File]() {
					if file.name == itemName {
						guard let identifier = file.identifier else {
							throw GoogleDriveError.noIdentifierFound
						}
						if let itemType = itemType {
							if !self.mimeTypeMatchCloudItemType(mimeType: file.mimeType, cloudItemType: itemType) {
								hasFoundItemWithWrongType = true
								continue
							}
						}
						return identifier
					}
				}
				if hasFoundItemWithWrongType {
					throw CloudProviderError.itemTypeMismatch
				}
				throw CloudProviderError.itemNotFound
			} else {
				throw GoogleDriveError.unexpectedResultType
			}
		}
	}

	// MARK: Operations with Google Drive Item Identifier

	private func deleteItem(withIdentifier identifier: String, at cloudPath: CloudPath) -> Promise<Void> {
		let query = GTLRDriveQuery_FilesDelete.query(withFileId: identifier)
		return executeQuery(query).then { result -> Void in
			guard result is Void else {
				throw GoogleDriveError.unexpectedResultType
			}
			try self.cloudIdentifierCache?.uncacheIdentifier(for: cloudPath)
			return
		}
	}

	private func fetchGTLRDriveFileList(forFolderAt cloudPath: CloudPath, withIdentifier identifier: String, withPageToken pageToken: String?) -> Promise<GTLRDrive_FileList> {
		let query = GTLRDriveQuery_FilesList.query()
		query.q = "'\(identifier)' in parents and trashed = false"
		query.pageSize = 1000
		query.pageToken = pageToken
		query.fields = "nextPageToken, files(id,mimeType,modifiedTime,name,size)"
		return executeQuery(query, cloudPath: cloudPath).then { result -> GTLRDrive_FileList in
			if let fileList = result as? GTLRDrive_FileList {
				return fileList
			} else {
				throw GoogleDriveError.unexpectedResultType
			}
		}
	}

	private func fetchGTLRDriveFile(forItemIdentifier itemIdentifier: String, at cloudPath: CloudPath) -> Promise<GTLRDrive_File> {
		let query = GTLRDriveQuery_FilesGet.query(withFileId: itemIdentifier)
		query.fields = "name, modifiedTime, size, mimeType"
		return executeQuery(query, cloudPath: cloudPath).then { result -> GTLRDrive_File in
			if let file = result as? GTLRDrive_File {
				return file
			} else {
				throw GoogleDriveError.unexpectedResultType
			}
		}
	}

	private func fetchItemMetadata(forItemIdentifier itemIdentifier: String, at cloudPath: CloudPath) -> Promise<CloudItemMetadata> {
		return fetchGTLRDriveFile(forItemIdentifier: itemIdentifier, at: cloudPath).then { file -> CloudItemMetadata in
			guard let name = file.name, let lastModifiedDate = file.modifiedTime?.date, let mimeType = file.mimeType else {
				throw GoogleDriveError.receivedIncompleteMetadata
			}
			let itemType = self.getCloudItemType(forMimeType: mimeType)
			return CloudItemMetadata(name: name, cloudPath: cloudPath, itemType: itemType, lastModifiedDate: lastModifiedDate, size: file.size?.intValue)
		}
	}

	private func downloadFile(withIdentifier identifier: String, from cloudPath: CloudPath, to localURL: URL) -> Promise<Void> {
		let query = GTLRDriveQuery_FilesGet.queryForMedia(withFileId: identifier)

		let request = credentials.driveService.request(for: query)
		let fetcher = credentials.driveService.fetcherService.fetcher(with: request as URLRequest)
		fetcher.destinationFileURL = localURL
		let progress = Progress(totalUnitCount: -1)
		fetcher.downloadProgressBlock = { _, totalBytesWritten, totalBytesExpectedToWrite in
			progress.totalUnitCount = totalBytesExpectedToWrite // Unnecessary to set several times
			progress.completedUnitCount = totalBytesWritten
		}
		runningFetchers.append(fetcher)
		return Promise<Void> { fulfill, reject in
			fetcher.beginFetch { _, error in
				self.runningFetchers.removeAll { $0 == fetcher }
				if let error = error as NSError? {
					if error.domain == kGTMSessionFetcherStatusDomain {
						if error.code == GoogleDriveConstants.googleDriveErrorCodeFileNotFound {
							do {
								try self.cloudIdentifierCache?.uncacheIdentifier(for: cloudPath)
								return reject(CloudProviderError.itemNotFound)
							} catch {
								return reject(error)
							}
						} else if error.code == GoogleDriveConstants.googleDriveErrorCodeInvalidCredentials {
							return reject(CloudProviderError.unauthorized)
						}
					}
					reject(error)
				} else {
					fulfill(())
				}
			}
		}
	}

	// MARK: Helper

	/**
	 A wrapper for the GTLRDriveQuery with Promises.
	 */
	private func executeQuery(_ query: GTLRDriveQuery, cloudPath: CloudPath? = nil) -> Promise<Any> {
		return Promise<Any> { fulfill, reject in
			let ticket = self.credentials.driveService.executeQuery(query) { ticket, result, error in
				self.runningTickets.removeAll { $0 == ticket }
				if let error = error as NSError? {
					if error.domain == NSURLErrorDomain, error.code == NSURLErrorNotConnectedToInternet || error.code == NSURLErrorCannotConnectToHost || error.code == NSURLErrorNetworkConnectionLost || error.code == NSURLErrorDNSLookupFailed || error.code == NSURLErrorResourceUnavailable || error.code == NSURLErrorInternationalRoamingOff {
						return reject(CloudProviderError.noInternetConnection)
					}
					if error.domain == kGTLRErrorObjectDomain, error.code == GoogleDriveConstants.googleDriveErrorCodeInvalidCredentials || error.code == GoogleDriveConstants.googleDriveErrorCodeForbidden {
						return reject(CloudProviderError.unauthorized)
					}
					if error.domain == kGTLRErrorObjectDomain, error.code == GoogleDriveConstants.googleDriveErrorCodeFileNotFound {
						if let cloudPath = cloudPath {
							do {
								try self.cloudIdentifierCache?.uncacheIdentifier(for: cloudPath)
							} catch {
								reject(error)
							}
						}
						return reject(CloudProviderError.itemNotFound)
					}
					return reject(error)
				}
				if let result = result {
					return fulfill(result)
				}
				fulfill(())
			}
			self.runningTickets.append(ticket)
		}
	}

	func getCloudItemType(forMimeType mimeType: String) -> CloudItemType {
		if mimeType == GoogleDriveConstants.folderMimeType {
			return .folder
		}
		return .file
	}

	func mimeTypeMatchCloudItemType(mimeType: String?, cloudItemType: CloudItemType) -> Bool {
		guard let mimeType = mimeType else {
			return false
		}
		let cloudItemTypeFromMimeType = getCloudItemType(forMimeType: mimeType)
		return cloudItemTypeFromMimeType == cloudItemType
	}

	func convertGTLRDriveFileListToCloudItemList(_ fileList: GTLRDrive_FileList, forFolderAt cloudPath: CloudPath) throws -> CloudItemList {
		var items = [CloudItemMetadata]()
		try fileList.files?.forEach { file in
			guard let name = file.name, let lastModifiedDate = file.modifiedTime?.date, let mimeType = file.mimeType else {
				throw CloudProviderError.itemNotFound
			}
			let itemType = getCloudItemType(forMimeType: mimeType)
			let itemCloudPath = cloudPath.appendingPathComponent(name)
			let itemMetadata = CloudItemMetadata(name: name, cloudPath: itemCloudPath, itemType: itemType, lastModifiedDate: lastModifiedDate, size: file.size?.intValue)
			items.append(itemMetadata)
		}
		let cloudItemList = CloudItemList(items: items, nextPageToken: fileList.nextPageToken)
		return cloudItemList
	}

	func onlyItemNameChangedBetween(_ lhs: CloudPath, and rhs: CloudPath) -> Bool {
		let lhsWithoutItemName = lhs.deletingLastPathComponent()
		let rhsWithoutItemName = rhs.deletingLastPathComponent()
		return lhsWithoutItemName == rhsWithoutItemName
	}

	private func createFolder(at cloudPath: CloudPath, withParentIdentifier parentIdentifier: String) -> Promise<Void> {
		let metadata = GTLRDrive_File()
		metadata.name = cloudPath.lastPathComponent
		metadata.parents = [parentIdentifier]
		metadata.mimeType = GoogleDriveConstants.folderMimeType
		let query = GTLRDriveQuery_FilesCreate.query(withObject: metadata, uploadParameters: nil)
		return executeQuery(query).then { result -> Void in
			if let folder = result as? GTLRDrive_File {
				guard let identifier = folder.identifier else {
					throw GoogleDriveError.noIdentifierFound
				}
				try self.cloudIdentifierCache?.cacheIdentifier(identifier, for: cloudPath)
			} else {
				throw GoogleDriveError.unexpectedResultType
			}
		}
	}

	/**
	 Traverses from the startCloudPath to the endCloudPath using the identifier that belongs to the startCloudPath
	 This is necessary because Google Drive does not use normal paths, but only works with (parent-)identifiers.
	 - Precondition: The `startCloudPath` points to a folder
	 - Precondition: The `startCloudPath` is a real subURL of endCloudPath
	 - Precondition: The `endCloudPath` points to a file
	 - Postcondition: If the cloudIdentifierCache exists, the identifier corresponding to the `endCloudPath` is cached in the cloudIdentifierCache.
	 - Parameter startCloudPath: The cloudPath of the folder from which the traversal is started
	 - Parameter endCloudPath: The cloudPath of the item, which is the actual target and from which the identifier is returned at the end
	 - Parameter startIdentifier: The identifier of the folder to which the `startCloudPath` points
	 - returns: Promise is fulfilled with the identifier that belongs to the `endCloudPath`
	 */
	private func traverseThroughPathToFile(from startCloudPath: CloudPath, to endCloudPath: CloudPath, withStartIdentifier startIdentifier: String) -> Promise<String> {
		assert(startCloudPath.pathComponents.count < endCloudPath.pathComponents.count)
		let endCloudPathParentFolder = endCloudPath.deletingLastPathComponent()
		let filename = endCloudPath.lastPathComponent
		if startCloudPath != endCloudPathParentFolder {
			return traverseThroughPathToFolder(from: startCloudPath, to: endCloudPathParentFolder, withStartIdentifier: startIdentifier).then { parentIdentifier in
				return self.getFirstIdentifier(forItemWithName: filename, itemType: .file, inFolderWithId: parentIdentifier)
			}.then { fileIdentifier -> String in
				try self.cloudIdentifierCache?.cacheIdentifier(fileIdentifier, for: endCloudPath)
				return fileIdentifier
			}
		}
		return getFirstIdentifier(forItemWithName: filename, itemType: .file, inFolderWithId: startIdentifier)
			.then { fileIdentifier -> String in
				try self.cloudIdentifierCache?.cacheIdentifier(fileIdentifier, for: endCloudPath)
				return fileIdentifier
			}
	}

	/**
	 Traverses from the startCloudPath to the endCloudPath using the identifier that belongs to the startCloudPath
	 This is necessary because Google Drive does not use normal paths, but only works with (parent-)identifiers.
	 To save on future requests, every intermediate path is also cached.
	 - Precondition: The `startCloudPath` points to a folder
	 - Precondition: The `startCloudPath` is a real subURL of endCloudPath
	 - Precondition: The `endCloudPath` points to a folder
	 - Postcondition: If the cloudIdentifierCache exists, each identifier belonging to the respective intermediate path or `endCloudPath` was cached in the database.
	 - Parameter startCloudPath: The cloudPath of the folder from which the traversal is started
	 - Parameter endCloudPath: The cloudPath of the item, which is the actual target and from which the identifier is returned at the end
	 - Parameter startIdentifier: The identifier of the folder to which the `startCloudPath` points
	 - returns: Promise is fulfilled with the identifier that belongs to the `endCloudPath`
	 */
	private func traverseThroughPathToFolder(from startCloudPath: CloudPath, to endCloudPath: CloudPath, withStartIdentifier startIdentifier: String) -> Promise<String> {
		assert(startCloudPath.pathComponents.count < endCloudPath.pathComponents.count)
		let startIndex = startCloudPath.pathComponents.count
		let endIndex = endCloudPath.pathComponents.count
		var currentURL = startCloudPath
		var parentIdentifier = startIdentifier
		return Promise(on: .global()) { fulfill, _ in
			for i in startIndex ..< endIndex {
				let itemName = endCloudPath.pathComponents[i]
				currentURL = currentURL.appendingPathComponent(itemName)
				parentIdentifier = try await (self.getFirstIdentifier(forItemWithName: itemName, itemType: .folder, inFolderWithId: parentIdentifier))
				try self.cloudIdentifierCache?.cacheIdentifier(parentIdentifier, for: currentURL)
			}
			fulfill(parentIdentifier)
		}
	}

	private func createFileUploadQuery(from localURL: URL, to cloudPath: CloudPath, parentIdentifier: String, replaceExisting: Bool) -> Promise<GTLRDriveQuery> {
		let metadata = GTLRDrive_File()
		metadata.name = cloudPath.lastPathComponent
		let uploadParameters = GTLRUploadParameters(fileURL: localURL, mimeType: GoogleDriveConstants.unknownMimeType)
//		uploadParameters.useBackgroundSession = true
		return resolvePath(forFileAt: cloudPath).then { identifier -> Promise<GTLRDriveQuery> in
			if !replaceExisting {
				return Promise(CloudProviderError.itemAlreadyExists)
			}
			let query = GTLRDriveQuery_FilesUpdate.query(withObject: metadata, fileId: identifier, uploadParameters: uploadParameters)
			return Promise(query)
		}.recover { error -> GTLRDriveQuery in
			guard case CloudProviderError.itemNotFound = error else {
				throw error
			}
			metadata.parents = [parentIdentifier]
			let query = GTLRDriveQuery_FilesCreate.query(withObject: metadata, uploadParameters: uploadParameters)
			return query
		}
	}

	/**
	 - Parameter cloudPath: The path for which the identifier of the parent folder is needed.
	 - Returns: the identifier for the parent folder of the passed `cloudPath`. If the folder cannot be found, the promise is rejected with `CloudProviderError.parentFolderDoesNotExist`.
	 */
	private func resolveParentPath(for cloudPath: CloudPath) -> Promise<String> {
		let parentCloudPath = cloudPath.deletingLastPathComponent()
		return resolvePath(forFolderAt: parentCloudPath).recover { error -> String in
			if case CloudProviderError.itemNotFound = error {
				throw CloudProviderError.parentFolderDoesNotExist
			} else {
				throw error
			}
		}
	}
}
