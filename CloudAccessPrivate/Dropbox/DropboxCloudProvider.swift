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
	let authentication: DropboxCloudAuthentication
	private var runningTasks: [DBTask]
	static let networkErrorResponse: DBNetworkErrorResponseBlock = { networkError, task in
		if networkError.isAuthError() {
			DBClientsManager.unlinkAndResetClients()
		} else if networkError.isRateLimitError() {
			let rateLimitError = networkError.asRateLimitError()
			let backOff = rateLimitError.backoff.doubleValue
			DispatchQueue.main.asyncAfter(deadline: .now() + backOff) {
				print("task retry count: \(task.retryCount)")
				print("task restart")
				task.restart()
			}
		}
	}

	public init(with authentication: DropboxCloudAuthentication) {
		self.authentication = authentication
		self.runningTasks = [DBTask]()
		// DBGlobalErrorResponseHandler.registerNetworkErrorResponseBlock(DropboxCloudProvider.networkErrorResponse)
	}

	public func fetchItemMetadata(at remoteURL: URL) -> Promise<CloudItemMetadata> {
		precondition(remoteURL.isFileURL)
		guard let authorizedClient = authentication.authorizedClient else {
			return Promise(CloudProviderError.unauthorized)
		}
		let task = authorizedClient.filesRoutes.getMetadata(remoteURL.path)
		runningTasks.append(task)
		return Promise<CloudItemMetadata> { fulfill, reject in
			task.setResponseBlock { metadata, routeError, _ in
				self.runningTasks.removeAll { $0 == task }
				if let routeError = routeError {
					if routeError.tag == DBFILESGetMetadataErrorTag.path, routeError.path.tag == DBFILESLookupErrorTag.notFound {
						reject(CloudProviderError.itemNotFound)
						return
					}
					reject(DropboxError.getMetadataError)
					return
				}
				/* if let networkError = networkError?.nsError {
				 	reject(networkError)
				 	return
				 } */
				guard let metadata = metadata else {
					reject(DropboxError.unexpectedError)
					return
				}
				do {
					let itemMetadata = try self.createCloudItemMetadata(from: metadata, at: remoteURL)
					fulfill(itemMetadata)
				} catch {
					reject(error)
				}
			}
		}
	}

	public func fetchItemList(forFolderAt _: URL, withPageToken _: String?) -> Promise<CloudItemList> {
		return Promise(CloudProviderError.noInternetConnection)
	}

	public func downloadFile(from _: URL, to _: URL, progress _: Progress?) -> Promise<CloudItemMetadata> {
		return Promise(CloudProviderError.noInternetConnection)
	}

	public func uploadFile(from localURL: URL, to remoteURL: URL, isUpdate: Bool, progress: Progress?) -> Promise<CloudItemMetadata> {
		precondition(localURL.isFileURL && remoteURL.isFileURL)
		precondition(!localURL.hasDirectoryPath && !remoteURL.hasDirectoryPath)

		var isDirectory: ObjCBool = false
		let fileExists = FileManager.default.fileExists(atPath: localURL.path, isDirectory: &isDirectory)
		if !fileExists {
			return Promise(CloudProviderError.itemNotFound)
		}
		if isDirectory.boolValue {
			return Promise(CloudProviderError.itemTypeMismatch)
		}
		let queue = DispatchQueue(label: "uploadFile-Dropbox", qos: .userInitiated)
		return retry(
			on: queue,
			attempts: 5,
			delay: 2,
			condition: { _, error in
				(error as? DropboxError) == .tooManyWriteOperations || (error as? DropboxError) == .internalServerError
			}
		) {
			self.batchUploadSingleFile(from: localURL, to: remoteURL, isUpdate: isUpdate, progress: progress)
		}
	}

	public func createFolder(at remoteURL: URL) -> Promise<Void> {
		precondition(remoteURL.hasDirectoryPath)

		return ensureParentFolderExists(for: remoteURL).then {
			self.createFolderAfterParentCheck(at: remoteURL)
		}
	}

	public func deleteItem(at remoteURL: URL) -> Promise<Void> {
		guard let authorizedClient = authentication.authorizedClient else {
			return Promise(CloudProviderError.unauthorized)
		}
		return Promise<Void> { fulfill, reject in
			authorizedClient.filesRoutes.delete_V2(remoteURL.path).setResponseBlock { result, routeError, networkError in
				if let routeError = routeError {
					if routeError.isPathLookup(), routeError.pathLookup.isNotFound() {
						reject(CloudProviderError.itemNotFound)
						return
					}
					reject(DropboxError.deleteFileError)
					return
				}
				if let networkError = networkError?.nsError {
					reject(networkError)
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

	public func moveItem(from _: URL, to _: URL) -> Promise<Void> {
		return Promise(CloudProviderError.noInternetConnection)
	}

	/**
	 This function may only be called if a check has been performed to see if the parent folder exists, because the dropbox SDK always creates the intermediate folders.
	 */
	private func createFolderAfterParentCheck(at remoteURL: URL) -> Promise<Void> {
		guard let authorizedClient = authentication.authorizedClient else {
			return Promise(CloudProviderError.unauthorized)
		}
		let task = authorizedClient.filesRoutes.createFolderV2(remoteURL.path)
		runningTasks.append(task)
		return Promise<Void> { fulfill, reject in
			task.setResponseBlock { result, routeError, networkError in
				self.runningTasks.removeAll { $0 == task }
				if let routeError = routeError {
					if routeError.tag == DBFILESCreateFolderErrorTag.path, routeError.path.tag == DBFILESWriteErrorTag.conflict {
						reject(CloudProviderError.itemAlreadyExists)
						return
					}
					reject(DropboxError.createFolderError)
					return
				}
				if let networkError = networkError?.nsError {
					reject(networkError)
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

	// MARK: Helper

	func createCloudItemMetadata(from metadata: DBFILESMetadata, at remoteURL: URL) throws -> CloudItemMetadata {
		let itemName = metadata.name

		if metadata is DBFILESFolderMetadata {
			return CloudItemMetadata(name: itemName, remoteURL: remoteURL, itemType: .folder, lastModifiedDate: nil, size: nil)
		}
		guard let fileMetadata = metadata as? DBFILESFileMetadata else {
			throw DropboxError.unexpectedError
		}
		return CloudItemMetadata(name: itemName, remoteURL: remoteURL, itemType: .file, lastModifiedDate: fileMetadata.serverModified, size: fileMetadata.size.intValue)
	}

	func ensureParentFolderExists(for remoteURL: URL) -> Promise<Void> {
		assert(remoteURL.isFileURL)
		let parentRemoteURL = remoteURL.deletingLastPathComponent()
		if parentRemoteURL == URL(fileURLWithPath: "/", isDirectory: true) {
			return Promise(())
		}
		return Promise<Void>(on: .global()) { fulfill, reject in
			do {
				_ = try await(self.fetchItemMetadata(at: parentRemoteURL))
				fulfill(())
			} catch CloudProviderError.itemNotFound {
				reject(CloudProviderError.parentFolderDoesNotExist)
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

	// Upload File

	private func batchUploadSingleFile(from localURL: URL, to remoteURL: URL, isUpdate: Bool, progress: Progress?) -> Promise<CloudItemMetadata> {
		guard let authorizedClient = authentication.authorizedClient else {
			return Promise(CloudProviderError.unauthorized)
		}
		let commitInfo = DBFILESCommitInfo(path: remoteURL.path, mode: isUpdate ? DBFILESWriteMode(overwrite: ()) : nil, autorename: nil, clientModified: nil, mute: nil, propertyGroups: nil, strictConflict: nil)
		let uploadProgress: DBProgressBlock = { _, totalBytesUploaded, totalBytesExpectedToUpload in
			progress?.totalUnitCount = totalBytesExpectedToUpload
			progress?.completedUnitCount = totalBytesUploaded
		}
		return Promise<CloudItemMetadata> { fulfill, reject in

			let task = authorizedClient.filesRoutes.batchUploadFiles([localURL: commitInfo], queue: nil, progressBlock: uploadProgress) { fileUrlsToBatchResultEntries, finishBatchRouteError, finishBatchRequestError, fileUrlsToRequestErrors in
				if !fileUrlsToRequestErrors.isEmpty {
					guard let requestError = fileUrlsToRequestErrors[localURL] else {
						reject(DropboxError.unexpectedError)
						return
					}
					guard let error = requestError.nsError else {
						reject(self.convertRequestErrorToDropboxError(requestError))
						if requestError.isBadInputError() {
							let inputError = requestError.asBadInputError()
							print(inputError.description())
						}
						print("localURL: \(localURL) remoteURL Path: \(remoteURL.path) error: \(self.convertRequestErrorToDropboxError(requestError))")
						return
					}
					reject(error)
					return
				}
				if finishBatchRouteError != nil {
					reject(DropboxError.asyncPollError)
					return
				}
				if let finishBatchRequestError = finishBatchRequestError?.nsError {
					reject(finishBatchRequestError)
					return
				}
				guard let result = fileUrlsToBatchResultEntries?[localURL] else {
					reject(DropboxError.unexpectedResult)
					return
				}
				guard result.isSuccess() else {
					let failure = result.failure
					if failure.isTooManyWriteOperations() {
						// retry
						reject(DropboxError.tooManyWriteOperations)
						return
					}
					reject(DropboxError.uploadFileError)
					return
				}

				let fileMetadata = result.success

				let itemMetadata = CloudItemMetadata(name: fileMetadata.name, remoteURL: remoteURL, itemType: .file, lastModifiedDate: fileMetadata.serverModified, size: fileMetadata.size.intValue)
				fulfill(itemMetadata)
			}
		}
	}
}
