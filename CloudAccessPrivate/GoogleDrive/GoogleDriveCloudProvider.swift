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
	private let fileNotFoundError = 404
	private let googleDriveServiceErrorCodeForbidden = 403
	private let googleDriveServiceErrorDomainUsageLimits = "usageLimits"
	private let googleDriveServiceErrorReasonUserRateLimitExceeded = "userRateLimitExceeded"
	private let googleDriveServiceErrorReasonRateLimitExceeded = "rateLimitExceeded"
	private lazy var driveService: GTLRDriveService = {
		var driveService = GTLRDriveService()
		driveService.authorizer = self.authentication.authorization
		driveService.isRetryEnabled = true
		driveService.retryBlock = { _, suggestedWillRetry, fetchError in
			if let fetchError = fetchError as NSError? {
				if fetchError.domain == kGTMSessionFetcherStatusDomain || fetchError.code == self.googleDriveServiceErrorCodeForbidden {
					return suggestedWillRetry
				}
				guard let data = fetchError.userInfo["data"] as? Data, let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any], let error = json["error"] else {
					return suggestedWillRetry
				}
				let googleDriveError = GTLRErrorObject(json: ["error": error])
				guard let errorItem = googleDriveError.errors?.first else {
					return suggestedWillRetry
				}
				return errorItem.domain == self.googleDriveServiceErrorDomainUsageLimits && (errorItem.reason == self.googleDriveServiceErrorReasonUserRateLimitExceeded || errorItem.reason == self.googleDriveServiceErrorReasonRateLimitExceeded)
			}
			return suggestedWillRetry
		}

		// MARK: Add configurationBlock with sharedContainerIdentifier

		driveService.fetcherService.isRetryEnabled = true
		driveService.fetcherService.retryBlock = { suggestedWillRetry, error, response in
			if let error = error as NSError? {
				if error.domain == kGTMSessionFetcherStatusDomain, error.code == self.googleDriveServiceErrorCodeForbidden {
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
		resolvePath(for: remoteURL).then { identifier in
			self.fetchItemMetadata(forItemIdentifier: identifier, at: remoteURL)
		}
	}

	public func fetchItemList(forFolderAt remoteURL: URL, withPageToken pageToken: String?) -> Promise<CloudItemList> {
		precondition(remoteURL.hasDirectoryPath)
		return resolvePath(for: remoteURL).then { identifier in
			self.fetchGTLRDriveFileList(forIdentifier: identifier, withPageToken: pageToken)
		}.then { fileList in
			let cloudItemList = try self.convertGTLRDriveFileListToCloudItemList(fileList, forFolderAt: remoteURL)
			return Promise(cloudItemList)
		}
	}

	public func downloadFile(from remoteURL: URL, to localURL: URL) -> Promise<CloudItemMetadata> {
		resolvePath(for: remoteURL).then { identifier in
			all(
				self.fetchItemMetadata(forItemIdentifier: identifier, at: remoteURL),
				self.downloadFile(withIdentifier: identifier, from: remoteURL, to: localURL)
			)
		}.then { metadata, _ in
			metadata
		}
	}

	public func uploadFile(from localURL: URL, to remoteURL: URL, isUpdate: Bool) -> Promise<CloudItemMetadata> {
		createQuery(upload: localURL, to: remoteURL, isUpdate: isUpdate).then { query in
			self.executeQuery(query)
		}.then { result -> CloudItemMetadata in
			if let uploadedFile = result as? GTLRDrive_File {
				guard let identifier = uploadedFile.identifier, let name = uploadedFile.name, let lastModifiedDate = uploadedFile.modifiedTime?.date, let mimeType = uploadedFile.mimeType else {
					throw CloudProviderError.uploadFileFailed
				}
				try self.cloudIdentifierCache?.cacheIdentifier(identifier, for: remoteURL)
				let itemType = self.getCloudItemType(forMimeType: mimeType)
				let metadata = CloudItemMetadata(name: name, size: uploadedFile.size, remoteURL: remoteURL, lastModifiedDate: lastModifiedDate, itemType: itemType)
				return metadata
			} else {
				throw GoogleDriveError.unexpectedResultType
			}
		}
	}

	public func createFolder(at remoteURL: URL) -> Promise<Void> {
		precondition(remoteURL.hasDirectoryPath)
		let parentFolderRemoteURL = remoteURL.deletingLastPathComponent()
		let foldername = remoteURL.lastPathComponent
		return Promise<Void>(on: .global()) { fulfill, reject in
			let parentIdentifier = try await(self.resolvePath(for: parentFolderRemoteURL))
			do {
				_ = try await(self.getFirstIdentifier(forItemWithName: foldername, inFolderWithId: parentIdentifier))
				reject(CloudProviderError.itemAlreadyExists)
			} catch CloudProviderError.itemNotFound {
				_ = try await(self.createFolder(at: remoteURL, withParentIdentifier: parentIdentifier))
				fulfill(())
			}
		}
	}

	public func deleteItem(at remoteURL: URL) -> Promise<Void> {
		resolvePath(for: remoteURL).then(deleteItem)
	}

	public func moveItem(from oldRemoteURL: URL, to newRemoteURL: URL) -> Promise<Void> {
		precondition(oldRemoteURL.hasDirectoryPath == newRemoteURL.hasDirectoryPath)
		let metadata = GTLRDrive_File()
		metadata.name = newRemoteURL.lastPathComponent

		return Promise<GTLRDriveQuery>(on: .global()) { fulfill, reject in
			do {
				_ = try await(self.resolvePath(for: newRemoteURL))
				reject(CloudProviderError.itemAlreadyExists)
			} catch CloudProviderError.itemNotFound {
				let itemIdentifier = try await(self.resolvePath(for: oldRemoteURL))

				let query = GTLRDriveQuery_FilesUpdate.query(withObject: metadata, fileId: itemIdentifier, uploadParameters: nil)
				if !self.onlyItemNameChangedBetween(oldRemoteURL: oldRemoteURL, and: newRemoteURL) {
					let newParentRemoteURL = newRemoteURL.deletingLastPathComponent()
					let newParentIdentifier = try await(self.resolvePath(for: newParentRemoteURL))

					let oldParentRemoteURL = oldRemoteURL.deletingLastPathComponent()
					let oldParentIdentifier = try await(self.resolvePath(for: oldParentRemoteURL))
					query.addParents = newParentIdentifier
					query.removeParents = oldParentIdentifier
				}
				fulfill(query)
			}
		}.then(executeQuery).then { result -> Void in
			guard result is Void else {
				throw GoogleDriveError.unexpectedResultType
			}
			return
		}
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
	private func getFirstIdentifier(forItemWithName itemName: String, inFolderWithId: String) -> Promise<String> {
		let query = GTLRDriveQuery_FilesList.query()
		query.q = "'\(inFolderWithId)' in parents and name contains '\(itemName)' and trashed = false"
		query.fields = "files(id, name, mimeType)"
		return executeQuery(query).then { result -> String in
			if let fileList = result as? GTLRDrive_FileList {
				for file in fileList.files ?? [GTLRDrive_File]() {
					if file.name == itemName {
						guard let identifier = file.identifier else {
							throw GoogleDriveError.noIdentifierFound
						}
						return identifier
					}
				}
				throw CloudProviderError.itemNotFound
			} else {
				throw GoogleDriveError.unexpectedResultType
			}
		}
	}

	// MARK: Operations with Google Drive Item Identifier

	private func deleteItem(withIdentifier identifier: String) -> Promise<Void> {
		let query = GTLRDriveQuery_FilesDelete.query(withFileId: identifier)
		return executeQuery(query).then { result -> Void in
			guard result is Void else {
				throw GoogleDriveError.unexpectedResultType
			}
			return
		}
	}

	private func fetchGTLRDriveFileList(forIdentifier identifier: String, withPageToken pageToken: String?) -> Promise<GTLRDrive_FileList> {
		let query = GTLRDriveQuery_FilesList.query()
		query.q = "'\(identifier)' in parents and trashed = false"
		query.pageSize = 1000
		query.pageToken = pageToken
		query.fields = "nextPageToken, files(id,mimeType,modifiedTime,name,size)"
		return executeQuery(query).then { result -> GTLRDrive_FileList in
			if let fileList = result as? GTLRDrive_FileList {
				return fileList
			} else {
				throw GoogleDriveError.unexpectedResultType
			}
		}
	}

	private func fetchGTLRDriveFile(forItemIdentifier itemIdentifier: String) -> Promise<GTLRDrive_File> {
		let query = GTLRDriveQuery_FilesGet.query(withFileId: itemIdentifier)
		query.fields = "name, modifiedTime, size, mimeType"
		return executeQuery(query).then { result -> GTLRDrive_File in
			if let file = result as? GTLRDrive_File {
				return file
			} else {
				throw GoogleDriveError.unexpectedResultType
			}
		}
	}

	private func fetchItemMetadata(forItemIdentifier itemIdentifier: String, at remoteURL: URL) -> Promise<CloudItemMetadata> {
		fetchGTLRDriveFile(forItemIdentifier: itemIdentifier).then { file -> CloudItemMetadata in
			guard let name = file.name, let lastModifiedDate = file.modifiedTime?.date, let mimeType = file.mimeType else {
				throw CloudProviderError.itemNotFound // MARK: Discuss Error
			}
			let itemType = self.getCloudItemType(forMimeType: mimeType)
			return CloudItemMetadata(name: name, size: file.size, remoteURL: remoteURL, lastModifiedDate: lastModifiedDate, itemType: itemType)
		}
	}

	private func downloadFile(withIdentifier identifier: String, from remoteURL: URL, to localURL: URL) -> Promise<Void> {
		let query = GTLRDriveQuery_FilesGet.queryForMedia(withFileId: identifier)
		let request = driveService.request(for: query)
		let fetcher = driveService.fetcherService.fetcher(with: request as URLRequest)
		fetcher.destinationFileURL = localURL
		runningFetchers.append(fetcher)
		return Promise<Void> { fulfill, reject in
			fetcher.beginFetch { _, error in

				// MARK: race condition

				self.runningFetchers.removeAll { $0 == fetcher }
				if let error = error as NSError? {
					if error.domain == kGTMSessionFetcherStatusDomain, error.code == self.fileNotFoundError {
						do {
							try self.cloudIdentifierCache?.uncacheIdentifier(for: remoteURL)
							reject(CloudProviderError.itemNotFound)
						} catch {
							reject(error)
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
	private func executeQuery(_ query: GTLRDriveQuery) -> Promise<Any> {
		Promise<Any> { fulfill, reject in
			let ticket = self.driveService.executeQuery(query) { ticket, result, error in

				// MARK: race condition

				self.runningTickets.removeAll { $0 == ticket }
				if let error = error {
					return reject(error)
				}
				if let result = result {
					return fulfill(result)
				}
				fulfill(())
			}

			// MARK: race condition

			self.runningTickets.append(ticket)
		}
	}

	func getCloudItemType(forMimeType mimeType: String) -> CloudItemType {
		if mimeType == folderMimeType {
			return .folder
		}
		return .file
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

			let itemMetadata = CloudItemMetadata(name: name, size: file.size, remoteURL: remoteItemURL, lastModifiedDate: lastModifiedDate, itemType: itemType)
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
				parentIdentifier = try await(self.getFirstIdentifier(forItemWithName: itemName, inFolderWithId: parentIdentifier))

				try self.cloudIdentifierCache?.cacheIdentifier(parentIdentifier, for: currentURL)
			}
			fulfill(parentIdentifier)
		}
	}

	private func createQuery(upload localURL: URL, to remoteURL: URL, isUpdate: Bool) -> Promise<GTLRDriveQuery> {
		if isUpdate {
			return createQuery(upload: localURL, to: remoteURL)
		} else {
			return createQueryForNewFileInCloud(upload: localURL, to: remoteURL)
		}
	}

	private func createQuery(upload localURL: URL, to remoteURL: URL) -> Promise<GTLRDriveQuery> {
		resolvePath(for: remoteURL).then { identifier -> GTLRDriveQuery in
			let metadata = GTLRDrive_File()
			metadata.name = remoteURL.lastPathComponent
			let uploadParameters = GTLRUploadParameters(fileURL: localURL, mimeType: self.unknownMimeType)
			let query = GTLRDriveQuery_FilesUpdate.query(withObject: metadata, fileId: identifier, uploadParameters: uploadParameters)
			return query
		}
	}

	// MARK: Change function name

	private func createQueryForNewFileInCloud(upload localURL: URL, to remoteURL: URL) -> Promise<GTLRDriveQuery> {
		Promise<GTLRDriveQuery>(on: .global()) { fulfill, reject in
			do {
				_ = try await(self.resolvePath(for: remoteURL))
				reject(CloudProviderError.itemAlreadyExists)
			} catch CloudProviderError.itemNotFound {
				let metadata = GTLRDrive_File()
				metadata.name = remoteURL.lastPathComponent
				let uploadParameters = GTLRUploadParameters(fileURL: localURL, mimeType: self.unknownMimeType)
				let query = GTLRDriveQuery_FilesCreate.query(withObject: metadata, uploadParameters: uploadParameters)
				fulfill(query)
			}
		}
	}
}
