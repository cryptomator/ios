//
//  GoogleDriveCloudProvider.swift
//  CloudAccessPrivate
//
//  Created by Philipp Schmid on 24.04.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import Foundation
import GoogleAPIClientForREST
import GRDB
import GTMSessionFetcher
import Promises

public class GoogleDriveCloudProvider: CloudProvider {
	private let authentication: GoogleDriveCloudAuthentication
	private let rootFolderId = "root"
	private let folderMimeType = "application/vnd.google-apps.folder"
	private let unknownMimeType = "application/octet-stream"
	private let googleDriveErrorCodeFileNotFound = 404
	private let googleDriveErrorCodeForbidden = 403
	private let googleDriveErrorCodeInvalidCredentials = 401
	private let googleDriveErrorDomainUsageLimits = "usageLimits"
	private let googleDriveErrorReasonUserRateLimitExceeded = "userRateLimitExceeded"
	private let googleDriveErrorReasonRateLimitExceeded = "rateLimitExceeded"
	private lazy var driveService: GTLRDriveService = {
		var driveService = GTLRDriveService()
		driveService.authorizer = self.authentication.authorization
		driveService.isRetryEnabled = true
		driveService.retryBlock = { _, suggestedWillRetry, fetchError in
			if let fetchError = fetchError as NSError? {
				if fetchError.domain == kGTMSessionFetcherStatusDomain || fetchError.code == self.googleDriveErrorCodeForbidden {
					return suggestedWillRetry
				}
				guard let data = fetchError.userInfo["data"] as? Data, let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any], let error = json["error"] else {
					return suggestedWillRetry
				}
				let googleDriveError = GTLRErrorObject(json: ["error": error])
				guard let errorItem = googleDriveError.errors?.first else {
					return suggestedWillRetry
				}
				return errorItem.domain == self.googleDriveErrorDomainUsageLimits && (errorItem.reason == self.googleDriveErrorReasonUserRateLimitExceeded || errorItem.reason == self.googleDriveErrorReasonRateLimitExceeded)
			}
			return suggestedWillRetry
		}

		// MARK: Add configurationBlock with sharedContainerIdentifier

		driveService.fetcherService.isRetryEnabled = true
		driveService.fetcherService.retryBlock = { suggestedWillRetry, error, response in
			if let error = error as NSError? {
				if error.domain == kGTMSessionFetcherStatusDomain, error.code == self.googleDriveErrorCodeForbidden {
					return response(true)
				}
			}
			response(suggestedWillRetry)
		}
		return driveService
	}()

	private let cloudIdentifierCache: GoogleDriveCloudIdentifierCacheManager?
	private var runningTickets: [GTLRServiceTicket]
	private var runningFetchers: [GTMSessionFetcher]

	public init(with authentication: GoogleDriveCloudAuthentication) {
		self.authentication = authentication
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

	public func fetchItemMetadata(at remoteURL: URL) -> Promise<CloudItemMetadata> {
		return resolvePath(for: remoteURL).then { identifier in
			self.fetchItemMetadata(forItemIdentifier: identifier, at: remoteURL)
		}
	}

	public func fetchItemList(forFolderAt remoteURL: URL, withPageToken pageToken: String?) -> Promise<CloudItemList> {
		precondition(remoteURL.hasDirectoryPath)
		return resolvePath(for: remoteURL).then { identifier in
			self.fetchGTLRDriveFileList(forFolderAt: remoteURL, withIdentifier: identifier, withPageToken: pageToken)
		}.then { fileList in
			let cloudItemList = try self.convertGTLRDriveFileListToCloudItemList(fileList, forFolderAt: remoteURL)
			return Promise(cloudItemList)
		}
	}

	public func downloadFile(from remoteURL: URL, to localURL: URL, progress: Progress?) -> Promise<Void> {
		precondition(!remoteURL.hasDirectoryPath)
		if FileManager.default.fileExists(atPath: localURL.path) {
			return Promise(CloudProviderError.itemAlreadyExists)
		}
		return resolvePath(for: remoteURL).then { identifier in
			self.downloadFile(withIdentifier: identifier, from: remoteURL, to: localURL, progress: progress)
		}
	}

	public func uploadFile(from localURL: URL, to remoteURL: URL, replaceExisting: Bool, progress: Progress?) -> Promise<CloudItemMetadata> {
		precondition(!localURL.hasDirectoryPath)
		precondition(!remoteURL.hasDirectoryPath)
		var isDirectory: ObjCBool = false
		let fileExists = FileManager.default.fileExists(atPath: localURL.path, isDirectory: &isDirectory)
		if !fileExists {
			return Promise(CloudProviderError.itemNotFound)
		}
		if isDirectory.boolValue {
			return Promise(CloudProviderError.itemTypeMismatch)
		}
		return resolveParentPath(for: remoteURL).then { parentIdentfier in
			self.createFileUploadQuery(from: localURL, to: remoteURL, parentIdentifier: parentIdentfier, replaceExisting: replaceExisting)
		}.then { query -> Promise<Any> in
			query.executionParameters.uploadProgressBlock = { _, totalBytesUploaded, totalBytesExpectedToUpload in
				progress?.totalUnitCount = Int64(totalBytesExpectedToUpload)
				progress?.completedUnitCount = Int64(totalBytesUploaded)
			}
			query.fields = "id, name, modifiedTime, mimeType"
			return self.executeQuery(query)
		}.then { result -> CloudItemMetadata in
			if let uploadedFile = result as? GTLRDrive_File {
				guard let identifier = uploadedFile.identifier, let name = uploadedFile.name, let lastModifiedDate = uploadedFile.modifiedTime?.date, let mimeType = uploadedFile.mimeType else {
					throw GoogleDriveError.receivedIncompleteMetadata
				}
				try self.cloudIdentifierCache?.cacheIdentifier(identifier, for: remoteURL)
				let itemType = self.getCloudItemType(forMimeType: mimeType)
				let metadata = CloudItemMetadata(name: name, remoteURL: remoteURL, itemType: itemType, lastModifiedDate: lastModifiedDate, size: uploadedFile.size?.intValue)
				return metadata
			} else {
				throw GoogleDriveError.unexpectedResultType
			}
		}
	}

	public func createFolder(at remoteURL: URL) -> Promise<Void> {
		precondition(remoteURL.hasDirectoryPath)

		let foldername = remoteURL.lastPathComponent
		return Promise<Void>(on: .global()) { fulfill, reject in
			let parentIdentifier = try await(self.resolveParentPath(for: remoteURL))
			do {
				_ = try await(self.getFirstIdentifier(forItemWithName: foldername, itemType: .folder, inFolderWithId: parentIdentifier))
				reject(CloudProviderError.itemAlreadyExists)
			} catch CloudProviderError.itemNotFound {
				_ = try await(self.createFolder(at: remoteURL, withParentIdentifier: parentIdentifier))
				fulfill(())
			} catch CloudProviderError.itemTypeMismatch {
				reject(CloudProviderError.itemAlreadyExists)
			}
		}
	}

	public func deleteItem(at remoteURL: URL) -> Promise<Void> {
		return resolvePath(for: remoteURL).then { identifier in
			self.deleteItem(withIdentifier: identifier, at: remoteURL)
		}
	}

	public func moveItem(from oldRemoteURL: URL, to newRemoteURL: URL) -> Promise<Void> {
		precondition(oldRemoteURL.hasDirectoryPath == newRemoteURL.hasDirectoryPath)
		let metadata = GTLRDrive_File()
		metadata.name = newRemoteURL.lastPathComponent

		return resolveParentPath(for: newRemoteURL).then { _ in
			self.checkForItemExistence(at: newRemoteURL)
		}.then { itemExists -> Void in
			if itemExists {
				throw CloudProviderError.itemAlreadyExists
			}
		}.then {
			self.resolvePath(for: oldRemoteURL)
		}.then { itemIdentifier -> Promise<GTLRDriveQuery_FilesUpdate> in
			let query = GTLRDriveQuery_FilesUpdate.query(withObject: metadata, fileId: itemIdentifier, uploadParameters: nil)
			return self.modificateQueryForMoveItem(query, from: oldRemoteURL, to: newRemoteURL)
		}.then { query in
			self.executeQuery(query, remoteURL: oldRemoteURL)
		}.then { result -> Void in
			guard let file = result as? GTLRDrive_File else {
				throw GoogleDriveError.unexpectedResultType
			}
			guard let identifier = file.identifier else {
				throw GoogleDriveError.receivedIncompleteMetadata
			}
			try self.cloudIdentifierCache?.uncacheIdentifier(for: oldRemoteURL)
			try self.cloudIdentifierCache?.cacheIdentifier(identifier, for: newRemoteURL)
			return
		}
	}

	private func modificateQueryForMoveItem(_ query: GTLRDriveQuery_FilesUpdate, from oldRemoteURL: URL, to newRemoteURL: URL) -> Promise<GTLRDriveQuery_FilesUpdate> {
		query.fields = "id, modifiedTime"
		if !onlyItemNameChangedBetween(oldRemoteURL: oldRemoteURL, and: newRemoteURL) {
			let oldParentRemoteURL = oldRemoteURL.deletingLastPathComponent()
			let newParentRemoteURL = newRemoteURL.deletingLastPathComponent()
			return all(resolvePath(for: oldParentRemoteURL), resolvePath(for: newParentRemoteURL)).then { oldParentIdentifier, newParentIdentifier -> GTLRDriveQuery_FilesUpdate in
				query.addParents = newParentIdentifier
				query.removeParents = oldParentIdentifier
				return query
			}
		}
		return Promise(query)
	}

	/**
	 Resolve remote URL to Google Drive Item Identifier
	 - Returns: ItemIdentifier on Google Drive, which belongs to the item to which the remoteURL points
	 */
	func resolvePath(for remoteURL: URL) -> Promise<String> {
		var urlToCheckForCache = remoteURL
		var cachedIdentifier = cloudIdentifierCache?.getIdentifier(for: urlToCheckForCache)
		while cachedIdentifier == nil, !urlToCheckForCache.pathComponents.isEmpty {
			urlToCheckForCache.deleteLastPathComponent()
			cachedIdentifier = cloudIdentifierCache?.getIdentifier(for: urlToCheckForCache)
		}
		if urlToCheckForCache != remoteURL {
			return traverseThroughPath(from: urlToCheckForCache, to: remoteURL, withStartIdentifier: cachedIdentifier!)
		}
		return Promise(cachedIdentifier!)
	}

	/**
	    workaround: https://stackoverflow.com/a/47282129/1759462
	 */
	private func getFirstIdentifier(forItemWithName itemName: String, itemType: CloudItemType, inFolderWithId: String) -> Promise<String> {
		let query = GTLRDriveQuery_FilesList.query()
		query.q = "'\(inFolderWithId)' in parents and name contains '\(itemName)' and trashed = false"
		query.fields = "files(id, name, mimeType)"
		var hasFoundItemWithWrongType = false
		return executeQuery(query).then { result -> String in
			if let fileList = result as? GTLRDrive_FileList {
				for file in fileList.files ?? [GTLRDrive_File]() {
					if file.name == itemName {
						if self.mimeTypeMatchCloudItemType(mimeType: file.mimeType, cloudItemType: itemType) {
							guard let identifier = file.identifier else {
								throw GoogleDriveError.noIdentifierFound
							}
							return identifier
						} else {
							hasFoundItemWithWrongType = true
						}
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

	private func deleteItem(withIdentifier identifier: String, at remoteURL: URL) -> Promise<Void> {
		let query = GTLRDriveQuery_FilesDelete.query(withFileId: identifier)
		return executeQuery(query).then { result -> Void in
			guard result is Void else {
				throw GoogleDriveError.unexpectedResultType
			}
			try self.cloudIdentifierCache?.uncacheIdentifier(for: remoteURL)
			return
		}
	}

	private func fetchGTLRDriveFileList(forFolderAt remoteURL: URL, withIdentifier identifier: String, withPageToken pageToken: String?) -> Promise<GTLRDrive_FileList> {
		let query = GTLRDriveQuery_FilesList.query()
		query.q = "'\(identifier)' in parents and trashed = false"
		query.pageSize = 1000
		query.pageToken = pageToken
		query.fields = "nextPageToken, files(id,mimeType,modifiedTime,name,size)"
		return executeQuery(query, remoteURL: remoteURL).then { result -> GTLRDrive_FileList in
			if let fileList = result as? GTLRDrive_FileList {
				return fileList
			} else {
				throw GoogleDriveError.unexpectedResultType
			}
		}
	}

	private func fetchGTLRDriveFile(forItemIdentifier itemIdentifier: String, at remoteURL: URL) -> Promise<GTLRDrive_File> {
		let query = GTLRDriveQuery_FilesGet.query(withFileId: itemIdentifier)
		query.fields = "name, modifiedTime, size, mimeType"
		return executeQuery(query, remoteURL: remoteURL).then { result -> GTLRDrive_File in
			if let file = result as? GTLRDrive_File {
				return file
			} else {
				throw GoogleDriveError.unexpectedResultType
			}
		}
	}

	private func fetchItemMetadata(forItemIdentifier itemIdentifier: String, at remoteURL: URL) -> Promise<CloudItemMetadata> {
		return fetchGTLRDriveFile(forItemIdentifier: itemIdentifier, at: remoteURL).then { file -> CloudItemMetadata in
			guard let name = file.name, let lastModifiedDate = file.modifiedTime?.date, let mimeType = file.mimeType else {
				throw GoogleDriveError.receivedIncompleteMetadata
			}
			let itemType = self.getCloudItemType(forMimeType: mimeType)
			return CloudItemMetadata(name: name, remoteURL: remoteURL, itemType: itemType, lastModifiedDate: lastModifiedDate, size: file.size?.intValue)
		}
	}

	private func downloadFile(withIdentifier identifier: String, from remoteURL: URL, to localURL: URL, progress: Progress?) -> Promise<Void> {
		let query = GTLRDriveQuery_FilesGet.queryForMedia(withFileId: identifier)
		let request = driveService.request(for: query)
		let fetcher = driveService.fetcherService.fetcher(with: request as URLRequest)
		fetcher.destinationFileURL = localURL
		fetcher.downloadProgressBlock = { _, totalBytesWritten, totalBytesExpectedToWrite in
			progress?.totalUnitCount = totalBytesExpectedToWrite // Unnecessary to set several times
			progress?.completedUnitCount = totalBytesWritten
		}
		runningFetchers.append(fetcher)
		return Promise<Void> { fulfill, reject in
			fetcher.beginFetch { _, error in
				self.runningFetchers.removeAll { $0 == fetcher }
				if let error = error as NSError? {
					if error.domain == kGTMSessionFetcherStatusDomain {
						if error.code == self.googleDriveErrorCodeFileNotFound {
							do {
								try self.cloudIdentifierCache?.uncacheIdentifier(for: remoteURL)
								return reject(CloudProviderError.itemNotFound)
							} catch {
								return reject(error)
							}
						} else if error.code == self.googleDriveErrorCodeInvalidCredentials {
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
	private func executeQuery(_ query: GTLRDriveQuery, remoteURL: URL? = nil) -> Promise<Any> {
		return Promise<Any> { fulfill, reject in
			let ticket = self.driveService.executeQuery(query) { ticket, result, error in
				self.runningTickets.removeAll { $0 == ticket }
				if let error = error as NSError? {
					if error.domain == NSURLErrorDomain, error.code == NSURLErrorNotConnectedToInternet || error.code == NSURLErrorCannotConnectToHost || error.code == NSURLErrorNetworkConnectionLost || error.code == NSURLErrorDNSLookupFailed || error.code == NSURLErrorResourceUnavailable || error.code == NSURLErrorInternationalRoamingOff {
						return reject(CloudProviderError.noInternetConnection)
					}
					if error.domain == kGTLRErrorObjectDomain, error.code == self.googleDriveErrorCodeInvalidCredentials || error.code == self.googleDriveErrorCodeForbidden {
						return reject(CloudProviderError.unauthorized)
					}
					if error.domain == kGTLRErrorObjectDomain, error.code == self.googleDriveErrorCodeFileNotFound {
						if let remoteURL = remoteURL {
							do {
								try self.cloudIdentifierCache?.uncacheIdentifier(for: remoteURL)
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
		if mimeType == folderMimeType {
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

	func convertGTLRDriveFileListToCloudItemList(_ fileList: GTLRDrive_FileList, forFolderAt remoteURL: URL) throws -> CloudItemList {
		assert(remoteURL.hasDirectoryPath)
		var items = [CloudItemMetadata]()
		try fileList.files?.forEach { file in
			guard let name = file.name, let lastModifiedDate = file.modifiedTime?.date, let mimeType = file.mimeType else {
				throw CloudProviderError.itemNotFound
			}
			let itemType = getCloudItemType(forMimeType: mimeType)
			let remoteItemURL = remoteURL.appendingPathComponent(name, isDirectory: itemType == .folder)
			let itemMetadata = CloudItemMetadata(name: name, remoteURL: remoteItemURL, itemType: itemType, lastModifiedDate: lastModifiedDate, size: file.size?.intValue)
			items.append(itemMetadata)
		}
		let cloudItemList = CloudItemList(items: items, nextPageToken: fileList.nextPageToken)
		return cloudItemList
	}

	func onlyItemNameChangedBetween(oldRemoteURL: URL, and newRemoteURL: URL) -> Bool {
		let oldRemoteURLWithoutItemName = oldRemoteURL.deletingLastPathComponent()
		let newRemoteURLWithoutItemName = newRemoteURL.deletingLastPathComponent()
		return oldRemoteURLWithoutItemName == newRemoteURLWithoutItemName
	}

	private func createFolder(at remoteURL: URL, withParentIdentifier parentIdentifier: String) -> Promise<Void> {
		assert(remoteURL.hasDirectoryPath)
		let metadata = GTLRDrive_File()
		metadata.name = remoteURL.lastPathComponent
		metadata.parents = [parentIdentifier]
		metadata.mimeType = folderMimeType
		let query = GTLRDriveQuery_FilesCreate.query(withObject: metadata, uploadParameters: nil)
		return executeQuery(query).then { result -> Void in
			if let folder = result as? GTLRDrive_File {
				guard let identifier = folder.identifier else {
					throw GoogleDriveError.noIdentifierFound
				}
				try self.cloudIdentifierCache?.cacheIdentifier(identifier, for: remoteURL)
			} else {
				throw GoogleDriveError.unexpectedResultType
			}
		}
	}

	// MARK: Change the function name to something more appropriate

	/**
	 Traverses from the start URL to the endRemoteURL using the identifier that belongs to the start URL
	 - Precondition: The startRemoteURL points to a folder
	 - Precondition: The startRemoteURL is a real subURL of endRemoteURL
	 - Parameter startRemoteURL: The remoteURL of the folder from which the traversal is started
	 - Parameter endRemoteURL: The remoteURL of the item, which is the actual target and from which the identifier is returned at the end
	 - Parameter startIdentifier: The identifier of the folder to which the startRemoteURL points
	 */
	private func traverseThroughPath(from startRemoteURL: URL, to endRemoteURL: URL, withStartIdentifier startIdentifier: String) -> Promise<String> {
		assert(startRemoteURL.pathComponents.count < endRemoteURL.pathComponents.count)
		assert(startRemoteURL.hasDirectoryPath)

		let startIndex = startRemoteURL.pathComponents.count
		let endIndex = endRemoteURL.pathComponents.count
		var currentURL = startRemoteURL
		var parentIdentifier = startIdentifier
		return Promise(on: .global()) { fulfill, _ in
			for i in startIndex ..< endIndex {
				let itemName = endRemoteURL.pathComponents[i]
				let isDirectory = (endRemoteURL.hasDirectoryPath || (i < endIndex - 1))
				currentURL.appendPathComponent(itemName, isDirectory: isDirectory)
				if isDirectory {
					parentIdentifier = try await(self.getFirstIdentifier(forItemWithName: itemName, itemType: .folder, inFolderWithId: parentIdentifier))
				} else {
					parentIdentifier = try await(self.getFirstIdentifier(forItemWithName: itemName, itemType: .file, inFolderWithId: parentIdentifier))
				}
				try self.cloudIdentifierCache?.cacheIdentifier(parentIdentifier, for: currentURL)
			}
			fulfill(parentIdentifier)
		}
	}

	private func createFileUploadQuery(from localURL: URL, to remoteURL: URL, parentIdentifier: String, replaceExisting: Bool) -> Promise<GTLRDriveQuery> {
		let metadata = GTLRDrive_File()
		metadata.name = remoteURL.lastPathComponent
		let uploadParameters = GTLRUploadParameters(fileURL: localURL, mimeType: unknownMimeType)

		return resolvePath(for: remoteURL).then { identifier -> Promise<GTLRDriveQuery> in
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

	private func resolveParentPath(for remoteURL: URL) -> Promise<String> {
		let parentRemoteURL = remoteURL.deletingLastPathComponent()
		return resolvePath(for: parentRemoteURL).recover { error -> String in
			if case CloudProviderError.itemNotFound = error {
				throw CloudProviderError.parentFolderDoesNotExist
			} else {
				throw error
			}
		}
	}
}
