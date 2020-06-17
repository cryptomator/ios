//
//  DropboxCloudProvider.swift
//  CloudAccessPrivate
//
//  Created by Philipp Schmid on 29.05.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import Foundation
import ObjectiveDropboxOfficial
import Promises
public class DropboxCloudProvider: CloudProvider {
	private let authentication: DropboxCloudAuthentication
	private var runningTasks: [DBTask]
	private var runningBatchUploadTasks: [DBBatchUploadTask]
	let shouldRetryForError: (Error) -> Bool = { error in
		return (error as? DropboxError) == .tooManyWriteOperations || (error as? DropboxError) == .internalServerError || (error as? DropboxError) == .rateLimitError
	}

	public init(with authentication: DropboxCloudAuthentication) {
		self.authentication = authentication
		self.runningTasks = [DBTask]()
		self.runningBatchUploadTasks = [DBBatchUploadTask]()
	}

	deinit {
		for task in runningTasks {
			task.cancel()
		}
		for task in runningBatchUploadTasks {
			task.cancel()
		}
	}

	public func fetchItemMetadata(at remoteURL: URL) -> Promise<CloudItemMetadata> {
		precondition(remoteURL.isFileURL)
		guard let authorizedClient = authentication.authorizedClient else {
			return Promise(CloudProviderError.unauthorized)
		}
		return retryWithExponentialBackoff({
			self.fetchItemMetadata(at: remoteURL, with: authorizedClient)
		}, condition: shouldRetryForError)
	}

	public func fetchItemList(forFolderAt remoteURL: URL, withPageToken pageToken: String?) -> Promise<CloudItemList> {
		precondition(remoteURL.isFileURL)
		precondition(remoteURL.hasDirectoryPath)
		guard let authorizedClient = authentication.authorizedClient else {
			return Promise(CloudProviderError.unauthorized)
		}
		return retryWithExponentialBackoff({
			self.fetchItemList(at: remoteURL, with: authorizedClient)
		}, condition: shouldRetryForError)
	}

	public func downloadFile(from remoteURL: URL, to localURL: URL, progress: Progress?) -> Promise<Void> {
		precondition(remoteURL.isFileURL && localURL.isFileURL)
		precondition(!localURL.hasDirectoryPath && !remoteURL.hasDirectoryPath)
		guard let authorizedClient = authentication.authorizedClient else {
			return Promise(CloudProviderError.unauthorized)
		}
		return retryWithExponentialBackoff({
			self.downloadFile(from: remoteURL, to: localURL, progress: progress, with: authorizedClient)
		}, condition: shouldRetryForError)
	}

	/**
	  Dropbox recommends uploading files over 150mb with a batchUpload.
	   - warning: This function is not atomic, because the existence of the parent folder is checked first, otherwise Dropbox creates the missing folders automatically.
	 */
	public func uploadFile(from localURL: URL, to remoteURL: URL, replaceExisting: Bool, progress: Progress?) -> Promise<CloudItemMetadata> {
		precondition(localURL.isFileURL && remoteURL.isFileURL)
		precondition(!localURL.hasDirectoryPath && !remoteURL.hasDirectoryPath)
		guard let authorizedClient = authentication.authorizedClient else {
			return Promise(CloudProviderError.unauthorized)
		}
		let attributes: [FileAttributeKey: Any]
		do {
			attributes = try FileManager.default.attributesOfItem(atPath: localURL.path)
		} catch CocoaError.fileReadNoSuchFile {
			return Promise(CloudProviderError.itemNotFound)
		} catch {
			return Promise(error)
		}
		let localItemType = getItemType(from: attributes[FileAttributeKey.type] as? FileAttributeType)
		guard localItemType == .file else {
			return Promise(CloudProviderError.itemTypeMismatch)
		}
		let mode = replaceExisting ? DBFILESWriteMode(overwrite: ()) : nil
		let fileSize = attributes[FileAttributeKey.size] as? Int ?? 157_286_400
		if fileSize >= 157_286_400 {
			return retryWithExponentialBackoff({ self.uploadBigFile(from: localURL, to: remoteURL, mode: mode, progress: progress, with: authorizedClient) }, condition: shouldRetryForError)
		} else {
			return retryWithExponentialBackoff({ self.uploadSmallFile(from: localURL, to: remoteURL, mode: mode, progress: progress, with: authorizedClient) }, condition: shouldRetryForError)
		}
	}

	/**
	 - warning: This function is not atomic, because the existence of the parent folder is checked first, otherwise Dropbox creates the missing folders automatically.
	 */
	public func createFolder(at remoteURL: URL) -> Promise<Void> {
		precondition(remoteURL.isFileURL)
		precondition(remoteURL.hasDirectoryPath)
		guard let authorizedClient = authentication.authorizedClient else {
			return Promise(CloudProviderError.unauthorized)
		}
		return retryWithExponentialBackoff({
			self.createFolder(at: remoteURL, with: authorizedClient)
		}, condition: shouldRetryForError)
	}

	/**
	 - warning: This function is not atomic, as the metadata must be retrieved first to ensure that there is no itemTypeMismatch.
	 */
	public func deleteItem(at remoteURL: URL) -> Promise<Void> {
		precondition(remoteURL.isFileURL)
		guard let authorizedClient = authentication.authorizedClient else {
			return Promise(CloudProviderError.unauthorized)
		}
		return retryWithExponentialBackoff({
			self.deleteItem(at: remoteURL, with: authorizedClient)
		}, condition: shouldRetryForError)
	}

	/**
	 - warning: This function is not atomic, as the metadata of the oldRemoteURL must first be retrieved to ensure that there is no itemTypeMismatch. In addition, the parentFolder of the newRemoteURL must be checked, otherwise Dropbox will automatically create the intermediate folders.
	 */
	public func moveItem(from oldRemoteURL: URL, to newRemoteURL: URL) -> Promise<Void> {
		precondition(oldRemoteURL.isFileURL && newRemoteURL.isFileURL)
		precondition(oldRemoteURL.hasDirectoryPath == newRemoteURL.hasDirectoryPath)
		guard let authorizedClient = authentication.authorizedClient else {
			return Promise(CloudProviderError.unauthorized)
		}
		return retryWithExponentialBackoff({ self.moveItem(from: oldRemoteURL, to: newRemoteURL, with: authorizedClient) }, condition: shouldRetryForError)
	}

	// fetchItemMetadata

	private func fetchItemMetadata(at remoteURL: URL, with client: DBUserClient) -> Promise<CloudItemMetadata> {
		return Promise<CloudItemMetadata> { fulfill, reject in
			let task = client.filesRoutes.getMetadata(remoteURL.path)
			self.runningTasks.append(task)
			task.setResponseBlock { metadata, routeError, networkError in
				self.runningTasks.removeAll { $0 == task }
				if let routeError = routeError {
					if routeError.isPath(), routeError.path.isNotFound() {
						reject(CloudProviderError.itemNotFound)
						return
					}
					reject(DropboxError.getMetadataError)
					return
				}
				if let networkError = networkError {
					reject(self.convertRequestErrorToDropboxError(networkError))
					return
				}
				guard let metadata = metadata else {
					reject(DropboxError.unexpectedError)
					return
				}
				do {
					let parentRemoteURL = remoteURL.deletingLastPathComponent()
					let itemMetadata = try self.createCloudItemMetadata(from: metadata, parentRemoteURL: parentRemoteURL)
					guard itemMetadata.itemType == self.getItemType(for: remoteURL) else {
						reject(CloudProviderError.itemTypeMismatch)
						return
					}
					fulfill(itemMetadata)
				} catch {
					reject(error)
				}
			}
		}
	}

	// fetchItemList

	private func fetchItemList(at remoteURL: URL, withPageToken pageToken: String?, with client: DBUserClient) -> Promise<CloudItemList> {
		if let pageToken = pageToken {
			return fetchItemListContinue(at: remoteURL, withPageToken: pageToken, with: client)
		} else {
			return fetchItemList(at: remoteURL, with: client)
		}
	}

	private func fetchItemList(at remoteURL: URL, with client: DBUserClient) -> Promise<CloudItemList> {
		let task = client.filesRoutes.listFolder(remoteURL.path)
		return Promise<CloudItemList> { fulfill, reject in
			self.runningTasks.append(task)
			task.setResponseBlock { result, routeError, networkError in
				self.runningTasks.removeAll { $0 == task }
				if let routeError = routeError {
					if routeError.isPath() {
						if routeError.path.isNotFound() {
							reject(CloudProviderError.itemNotFound)
							return
						}
						if routeError.path.isNotFolder() {
							reject(CloudProviderError.itemTypeMismatch)
							return
						}
					}
					reject(DropboxError.listFolderError)
					return
				}
				if let networkError = networkError {
					reject(self.convertRequestErrorToDropboxError(networkError))
					return
				}
				guard let result = result else {
					reject(DropboxError.unexpectedError)
					return
				}
				do {
					let itemList = try self.convertDBFILESListFolderResultToCloudItemList(result, forFolderAt: remoteURL)
					fulfill(itemList)
				} catch {
					reject(error)
				}
			}
		}
	}

	private func fetchItemListContinue(at remoteURL: URL, withPageToken pageToken: String, with client: DBUserClient) -> Promise<CloudItemList> {
		let task = client.filesRoutes.listFolderContinue(pageToken)

		return Promise<CloudItemList> { fulfill, reject in
			self.runningTasks.append(task)
			task.setResponseBlock { result, routeError, networkError in
				self.runningTasks.removeAll { $0 == task }
				if let routeError = routeError {
					if routeError.isPath() {
						if routeError.path.isNotFound() {
							reject(CloudProviderError.itemNotFound)
							return
						}
						if routeError.path.isNotFolder() {
							reject(CloudProviderError.itemTypeMismatch)
							return
						}
					}
					reject(DropboxError.listFolderError)
					return
				}
				if let networkError = networkError {
					reject(self.convertRequestErrorToDropboxError(networkError))
					return
				}
				guard let result = result else {
					reject(DropboxError.unexpectedError)
					return
				}
				do {
					let itemList = try self.convertDBFILESListFolderResultToCloudItemList(result, forFolderAt: remoteURL)
					fulfill(itemList)
				} catch {
					reject(error)
				}
			}
		}
	}

	// downloadFile

	private func downloadFile(from remoteURL: URL, to localURL: URL, progress: Progress?, with client: DBUserClient) -> Promise<Void> {
		let task = client.filesRoutes.downloadUrl(remoteURL.path, overwrite: false, destination: localURL)
		task.setProgressBlock { _, totalBytesWritten, totalBytesExpectedToWrite in
			progress?.totalUnitCount = totalBytesExpectedToWrite
			progress?.completedUnitCount = totalBytesWritten
		}
		return Promise<Void> { fulfill, reject in
			self.runningTasks.append(task)
			task.setResponseBlock { _, routeError, requestError, _ in
				self.runningTasks.removeAll { $0 == task }
				if let routeError = routeError {
					if routeError.isPath(), routeError.path.isNotFound() {
						reject(CloudProviderError.itemNotFound)
						return
					}
				}
				if let requestError = requestError {
					if requestError.isClientError() {
						let clientError = requestError.asClientError().nsError
						if case CocoaError.fileWriteFileExists = clientError {
							reject(CloudProviderError.itemAlreadyExists)
							return
						}
					}
					reject(self.convertRequestErrorToDropboxError(requestError))
					return
				}
				fulfill(())
			}
		}
	}

	// uploadFile

	private func uploadBigFile(from localURL: URL, to remoteURL: URL, mode: DBFILESWriteMode?, progress: Progress?, with client: DBUserClient) -> Promise<CloudItemMetadata> {
		return ensureParentFolderExists(for: remoteURL).then {
			self.batchUploadSingleFile(from: localURL, to: remoteURL, mode: mode, progress: progress, with: client)
		}
	}

	private func batchUploadSingleFile(from localURL: URL, to remoteURL: URL, mode: DBFILESWriteMode?, progress: Progress?, with client: DBUserClient) -> Promise<CloudItemMetadata> {
		let commitInfo = DBFILESCommitInfo(path: remoteURL.path, mode: mode, autorename: nil, clientModified: nil, mute: nil, propertyGroups: nil, strictConflict: true)
		let uploadProgress: DBProgressBlock = { _, totalBytesUploaded, totalBytesExpectedToUpload in
			progress?.totalUnitCount = totalBytesExpectedToUpload
			progress?.completedUnitCount = totalBytesUploaded
		}
		return Promise<CloudItemMetadata> { fulfill, reject in
			var task: DBBatchUploadTask!
			task = client.filesRoutes.batchUploadFiles([localURL: commitInfo], queue: nil, progressBlock: uploadProgress) {
				fileUrlsToBatchResultEntries, finishBatchRouteError, finishBatchRequestError, fileUrlsToRequestErrors in
				self.runningBatchUploadTasks.removeAll { $0 == task }
				guard let result = fileUrlsToBatchResultEntries?[localURL] else {
					if !fileUrlsToRequestErrors.isEmpty {
						guard let requestError = fileUrlsToRequestErrors[localURL] else {
							reject(DropboxError.unexpectedError)
							return
						}
						reject(self.convertRequestErrorToDropboxError(requestError))
						return
					}
					if finishBatchRouteError != nil {
						reject(DropboxError.asyncPollError)
						return
					}
					if let finishBatchRequestError = finishBatchRequestError {
						reject(self.convertRequestErrorToDropboxError(finishBatchRequestError))
						return
					}
					reject(DropboxError.uploadFileError)
					return
				}
				if result.isSuccess() {
					let fileMetadata = result.success
					let itemMetadata = self.createCloudItemMetadata(from: fileMetadata, parentRemoteURL: remoteURL.deletingLastPathComponent())
					fulfill(itemMetadata)
					return
				}
				if result.isFailure() {
					let failure = result.failure
					if failure.isTooManyWriteOperations() {
						reject(DropboxError.tooManyWriteOperations)
						return
					}
					if failure.isPath(), failure.path.isConflict() {
						reject(CloudProviderError.itemAlreadyExists)
						return
					}
					reject(DropboxError.uploadFileError)
				} else {
					reject(DropboxError.unexpectedResult)
				}
			}
			self.runningBatchUploadTasks.append(task)
		}
	}

	private func uploadSmallFile(from localURL: URL, to remoteURL: URL, mode: DBFILESWriteMode?, progress: Progress?, with client: DBUserClient) -> Promise<CloudItemMetadata> {
		return ensureParentFolderExists(for: remoteURL).then {
			self.uploadFileAfterParentCheck(from: localURL, to: remoteURL, mode: mode, progress: progress, with: client)
		}
	}

	private func uploadFileAfterParentCheck(from localURL: URL, to remoteURL: URL, mode: DBFILESWriteMode?, progress: Progress?, with client: DBUserClient) -> Promise<CloudItemMetadata> {
		let task = client.filesRoutes.uploadUrl(remoteURL.path, mode: mode, autorename: nil, clientModified: nil, mute: nil, propertyGroups: nil, strictConflict: true, inputUrl: localURL.path)
		runningTasks.append(task)
		return Promise<CloudItemMetadata> { fulfill, reject in
			task.setResponseBlock { result, routeError, networkError in
				self.runningTasks.removeAll { $0 == task }
				guard let result = result else {
					if let routeError = routeError {
						if routeError.isPath() {
							if routeError.path.reason.isTooManyWriteOperations() {
								reject(DropboxError.tooManyWriteOperations)
								return
							}
							if routeError.path.reason.isConflict() {
								reject(CloudProviderError.itemAlreadyExists)
								return
							}
						}
					}
					if let networkError = networkError {
						reject(self.convertRequestErrorToDropboxError(networkError))
						return
					}
					reject(DropboxError.unexpectedError)
					return
				}

				let metadata = self.createCloudItemMetadata(from: result, parentRemoteURL: remoteURL.deletingLastPathComponent())
				fulfill(metadata)
			}
		}
	}

	// createFolder

	private func createFolder(at remoteURL: URL, with client: DBUserClient) -> Promise<Void> {
		return ensureParentFolderExists(for: remoteURL).then {
			self.createFolderAfterParentCheck(at: remoteURL, with: client)
		}
	}

	/**
	 This function may only be called if a check has been performed to see if the parent folder exists, because the dropbox SDK always creates the intermediate folders.
	 */
	private func createFolderAfterParentCheck(at remoteURL: URL, with client: DBUserClient) -> Promise<Void> {
		let task = client.filesRoutes.createFolderV2(remoteURL.path)
		return Promise<Void> { fulfill, reject in
			self.runningTasks.append(task)
			task.setResponseBlock { result, routeError, networkError in
				self.runningTasks.removeAll { $0 == task }
				if let routeError = routeError {
					if routeError.tag == DBFILESCreateFolderErrorTag.path, routeError.path.tag == DBFILESWriteErrorTag.conflict {
						reject(CloudProviderError.itemAlreadyExists)
						return
					}
					reject(DropboxError.createFolderError)
				}
				if let networkError = networkError {
					reject(self.convertRequestErrorToDropboxError(networkError))
					return
				}
				guard result != nil else {
					reject(DropboxError.unexpectedError)
					return
				}
				fulfill(())
			}
		}
	}

	// Delete Item

	private func deleteItem(at remoteURL: URL, with client: DBUserClient) -> Promise<Void> {
		return fetchItemMetadata(at: remoteURL).then { metadata in
			guard self.getItemType(for: remoteURL) == metadata.itemType else {
				return Promise(CloudProviderError.itemTypeMismatch)
			}
			return self.deleteItemAfterTypeCheck(from: remoteURL, with: client)
		}
	}

	private func deleteItemAfterTypeCheck(from remoteURL: URL, with client: DBUserClient) -> Promise<Void> {
		return Promise<Void> { fulfill, reject in
			let task = client.filesRoutes.delete_V2(remoteURL.path)
			self.runningTasks.append(task)
			task.setResponseBlock { result, routeError, networkError in
				self.runningTasks.removeAll { $0 == task }
				if let routeError = routeError {
					if routeError.isPathLookup(), routeError.pathLookup.isNotFound() {
						reject(CloudProviderError.itemNotFound)
						return
					}
					reject(DropboxError.deleteFileError)
					return
				}
				if let networkError = networkError {
					reject(self.convertRequestErrorToDropboxError(networkError))
					return
				}
				guard result != nil else {
					reject(DropboxError.unexpectedError)
					return
				}
				fulfill(())
			}
		}
	}

	// Move Item

	private func moveItem(from oldRemoteURL: URL, to newRemoteURL: URL, with client: DBUserClient) -> Promise<Void> {
		assert(oldRemoteURL.isFileURL)
		assert(newRemoteURL.isFileURL)
		assert(oldRemoteURL.hasDirectoryPath == newRemoteURL.hasDirectoryPath)
		return all(ensureParentFolderExists(for: newRemoteURL), fetchItemMetadata(at: oldRemoteURL)).then { _, metadata in
			guard self.getItemType(for: oldRemoteURL) == metadata.itemType else {
				return Promise(CloudProviderError.itemTypeMismatch)
			}
			return self.moveItemAfterParentAndTypeCheck(from: oldRemoteURL, to: newRemoteURL, with: client)
		}
	}

	private func moveItemAfterParentAndTypeCheck(from oldRemoteURL: URL, to newRemoteURL: URL, with client: DBUserClient) -> Promise<Void> {
		assert(oldRemoteURL.isFileURL)
		assert(newRemoteURL.isFileURL)
		assert(oldRemoteURL.hasDirectoryPath == newRemoteURL.hasDirectoryPath)
		return Promise<Void> { fulfill, reject in
			let task = client.filesRoutes.moveV2(oldRemoteURL.path, toPath: newRemoteURL.path)
			self.runningTasks.append(task)
			task.setResponseBlock { _, routeError, networkError in
				self.runningTasks.removeAll { $0 == task }
				if let routeError = routeError {
					if routeError.isFromLookup(), routeError.fromLookup.isNotFound() {
						reject(CloudProviderError.itemNotFound)
						return
					}
					if routeError.isFromWrite(), routeError.fromWrite.isTooManyWriteOperations() {
						reject(DropboxError.tooManyWriteOperations)
					}
					if routeError.isTo(), routeError.to.isConflict() {
						reject(CloudProviderError.itemAlreadyExists)
					}
				}
				if let networkError = networkError {
					reject(self.convertRequestErrorToDropboxError(networkError))
					return
				}
				fulfill(())
			}
		}
	}

	// MARK: Helper

	func createCloudItemMetadata(from metadata: DBFILESMetadata, parentRemoteURL: URL) throws -> CloudItemMetadata {
		assert(parentRemoteURL.hasDirectoryPath)
		assert(parentRemoteURL.isFileURL)

		if metadata is DBFILESFolderMetadata {
			let itemName = metadata.name
			let remoteURL = parentRemoteURL.appendingPathComponent(itemName, isDirectory: true)
			return CloudItemMetadata(name: itemName, remoteURL: remoteURL, itemType: .folder, lastModifiedDate: nil, size: nil)
		}
		guard let fileMetadata = metadata as? DBFILESFileMetadata else {
			throw DropboxError.unexpectedError
		}
		return createCloudItemMetadata(from: fileMetadata, parentRemoteURL: parentRemoteURL)
	}

	func createCloudItemMetadata(from metadata: DBFILESFileMetadata, parentRemoteURL: URL) -> CloudItemMetadata {
		assert(parentRemoteURL.hasDirectoryPath)
		assert(parentRemoteURL.isFileURL)
		let itemName = metadata.name
		let remoteURL = parentRemoteURL.appendingPathComponent(itemName, isDirectory: false)
		return CloudItemMetadata(name: itemName, remoteURL: remoteURL, itemType: .file, lastModifiedDate: metadata.serverModified, size: metadata.size.intValue)
	}

	func ensureParentFolderExists(for remoteURL: URL) -> Promise<Void> {
		assert(remoteURL.isFileURL)
		let parentRemoteURL = remoteURL.deletingLastPathComponent()
		if parentRemoteURL == URL(fileURLWithPath: "/", isDirectory: true) {
			return Promise(())
		}
		return checkForItemExistence(at: parentRemoteURL).then { itemExists -> Void in
			guard itemExists else {
				throw CloudProviderError.parentFolderDoesNotExist
			}
		}
	}

	func convertRequestErrorToDropboxError(_ error: DBRequestError) -> DropboxError {
		if error.isInternalServerError() {
			return .internalServerError
		}
		if error.isBadInputError() {
			return .badInputError
		}
		if error.isAuthError() {
			return .authError
		}
		if error.isAccessError() {
			return .accessError
		}
		if error.isRateLimitError() {
			return .rateLimitError
		}
		if error.isHttpError() {
			return .httpError
		}
		if error.isClientError() {
			return .clientError
		} else {
			return DropboxError.unexpectedError
		}
	}

	func convertDBFILESListFolderResultToCloudItemList(_ folderResult: DBFILESListFolderResult, forFolderAt remoteURL: URL) throws -> CloudItemList {
		assert(remoteURL.hasDirectoryPath)
		assert(remoteURL.isFileURL)
		var items = [CloudItemMetadata]()
		for item in folderResult.entries {
			let metadata = try createCloudItemMetadata(from: item, parentRemoteURL: remoteURL)
			items.append(metadata)
		}

		if folderResult.hasMore.boolValue {
			return CloudItemList(items: items, nextPageToken: folderResult.cursor)
		}
		return CloudItemList(items: items)
	}

	func retryWithExponentialBackoff<Value>(_ work: @escaping () throws -> Promise<Value>, condition: (Error) -> Bool) -> Promise<Value> {
		let queue = DispatchQueue(label: "retryWithExponentialBackoff-Dropbox", qos: .userInitiated)
		let attempts = 5
		let exponentialBackoffBase: UInt = 2
		let exponentialBackoffScale = 0.5
		return retry(
			on: queue,
			attempts: attempts,
			delay: 0.01,
			condition: { remainingAttempts, error in
				let condition = self.shouldRetryForError(error)
				if condition {
					let retryCount = attempts - remainingAttempts
					let sleepTime = pow(Double(exponentialBackoffBase), Double(retryCount)) * exponentialBackoffScale
					sleep(UInt32(sleepTime))
				}
				return condition
			},
			work
		)
	}

	func getItemType(for remoteURL: URL) -> CloudItemType {
		precondition(remoteURL.isFileURL)
		if remoteURL.hasDirectoryPath {
			return .folder
		}
		return .file
	}

	func getItemType(from fileAttributeType: FileAttributeType?) -> CloudItemType {
		guard let type = fileAttributeType else {
			return CloudItemType.unknown
		}
		switch type {
		case .typeDirectory:
			return CloudItemType.folder
		case .typeRegular:
			return CloudItemType.file
		default:
			return CloudItemType.unknown
		}
	}
}
