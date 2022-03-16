//
//  CloudProviderMock.swift
//  CryptomatorTests
//
//  Created by Philipp Schmid on 27.10.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation
import Promises

// swiftlint:disable all
final class CloudProviderMock: CloudProvider {
	// MARK: - fetchItemMetadata

	var fetchItemMetadataAtCallsCount = 0
	var fetchItemMetadataAtCalled: Bool {
		fetchItemMetadataAtCallsCount > 0
	}

	var fetchItemMetadataAtReceivedCloudPath: CloudPath?
	var fetchItemMetadataAtReceivedInvocations: [CloudPath] = []
	var fetchItemMetadataAtReturnValue: Promise<CloudItemMetadata>!
	var fetchItemMetadataAtClosure: ((CloudPath) -> Promise<CloudItemMetadata>)?

	func fetchItemMetadata(at cloudPath: CloudPath) -> Promise<CloudItemMetadata> {
		fetchItemMetadataAtCallsCount += 1
		fetchItemMetadataAtReceivedCloudPath = cloudPath
		fetchItemMetadataAtReceivedInvocations.append(cloudPath)
		return fetchItemMetadataAtClosure.map({ $0(cloudPath) }) ?? fetchItemMetadataAtReturnValue
	}

	// MARK: - fetchItemList

	var fetchItemListForFolderAtWithPageTokenCallsCount = 0
	var fetchItemListForFolderAtWithPageTokenCalled: Bool {
		fetchItemListForFolderAtWithPageTokenCallsCount > 0
	}

	var fetchItemListForFolderAtWithPageTokenReceivedArguments: (cloudPath: CloudPath, pageToken: String?)?
	var fetchItemListForFolderAtWithPageTokenReceivedInvocations: [(cloudPath: CloudPath, pageToken: String?)] = []
	var fetchItemListForFolderAtWithPageTokenReturnValue: Promise<CloudItemList>!
	var fetchItemListForFolderAtWithPageTokenClosure: ((CloudPath, String?) -> Promise<CloudItemList>)?

	func fetchItemList(forFolderAt cloudPath: CloudPath, withPageToken pageToken: String?) -> Promise<CloudItemList> {
		fetchItemListForFolderAtWithPageTokenCallsCount += 1
		fetchItemListForFolderAtWithPageTokenReceivedArguments = (cloudPath: cloudPath, pageToken: pageToken)
		fetchItemListForFolderAtWithPageTokenReceivedInvocations.append((cloudPath: cloudPath, pageToken: pageToken))
		return fetchItemListForFolderAtWithPageTokenClosure.map({ $0(cloudPath, pageToken) }) ?? fetchItemListForFolderAtWithPageTokenReturnValue
	}

	// MARK: - downloadFile

	var downloadFileFromToCallsCount = 0
	var downloadFileFromToCalled: Bool {
		downloadFileFromToCallsCount > 0
	}

	var downloadFileFromToReceivedArguments: (cloudPath: CloudPath, localURL: URL)?
	var downloadFileFromToReceivedInvocations: [(cloudPath: CloudPath, localURL: URL)] = []
	var downloadFileFromToReturnValue: Promise<Void>!
	var downloadFileFromToClosure: ((CloudPath, URL) -> Promise<Void>)?

	func downloadFile(from cloudPath: CloudPath, to localURL: URL) -> Promise<Void> {
		downloadFileFromToCallsCount += 1
		downloadFileFromToReceivedArguments = (cloudPath: cloudPath, localURL: localURL)
		downloadFileFromToReceivedInvocations.append((cloudPath: cloudPath, localURL: localURL))
		return downloadFileFromToClosure.map({ $0(cloudPath, localURL) }) ?? downloadFileFromToReturnValue
	}

	// MARK: - uploadFile

	var uploadFileFromToReplaceExistingCallsCount = 0
	var uploadFileFromToReplaceExistingCalled: Bool {
		uploadFileFromToReplaceExistingCallsCount > 0
	}

	var uploadFileFromToReplaceExistingReceivedArguments: (localURL: URL, cloudPath: CloudPath, replaceExisting: Bool)?
	var uploadFileFromToReplaceExistingReceivedInvocations: [(localURL: URL, cloudPath: CloudPath, replaceExisting: Bool)] = []
	var uploadFileFromToReplaceExistingReturnValue: Promise<CloudItemMetadata>!
	var uploadFileFromToReplaceExistingClosure: ((URL, CloudPath, Bool) -> Promise<CloudItemMetadata>)?

	func uploadFile(from localURL: URL, to cloudPath: CloudPath, replaceExisting: Bool) -> Promise<CloudItemMetadata> {
		uploadFileFromToReplaceExistingCallsCount += 1
		uploadFileFromToReplaceExistingReceivedArguments = (localURL: localURL, cloudPath: cloudPath, replaceExisting: replaceExisting)
		uploadFileFromToReplaceExistingReceivedInvocations.append((localURL: localURL, cloudPath: cloudPath, replaceExisting: replaceExisting))
		return uploadFileFromToReplaceExistingClosure.map({ $0(localURL, cloudPath, replaceExisting) }) ?? uploadFileFromToReplaceExistingReturnValue
	}

	// MARK: - createFolder

	var createFolderAtCallsCount = 0
	var createFolderAtCalled: Bool {
		createFolderAtCallsCount > 0
	}

	var createFolderAtReceivedCloudPath: CloudPath?
	var createFolderAtReceivedInvocations: [CloudPath] = []
	var createFolderAtReturnValue: Promise<Void>!
	var createFolderAtClosure: ((CloudPath) -> Promise<Void>)?

	func createFolder(at cloudPath: CloudPath) -> Promise<Void> {
		createFolderAtCallsCount += 1
		createFolderAtReceivedCloudPath = cloudPath
		createFolderAtReceivedInvocations.append(cloudPath)
		return createFolderAtClosure.map({ $0(cloudPath) }) ?? createFolderAtReturnValue
	}

	// MARK: - deleteFile

	var deleteFileAtCallsCount = 0
	var deleteFileAtCalled: Bool {
		deleteFileAtCallsCount > 0
	}

	var deleteFileAtReceivedCloudPath: CloudPath?
	var deleteFileAtReceivedInvocations: [CloudPath] = []
	var deleteFileAtReturnValue: Promise<Void>!
	var deleteFileAtClosure: ((CloudPath) -> Promise<Void>)?

	func deleteFile(at cloudPath: CloudPath) -> Promise<Void> {
		deleteFileAtCallsCount += 1
		deleteFileAtReceivedCloudPath = cloudPath
		deleteFileAtReceivedInvocations.append(cloudPath)
		return deleteFileAtClosure.map({ $0(cloudPath) }) ?? deleteFileAtReturnValue
	}

	// MARK: - deleteFolder

	var deleteFolderAtCallsCount = 0
	var deleteFolderAtCalled: Bool {
		deleteFolderAtCallsCount > 0
	}

	var deleteFolderAtReceivedCloudPath: CloudPath?
	var deleteFolderAtReceivedInvocations: [CloudPath] = []
	var deleteFolderAtReturnValue: Promise<Void>!
	var deleteFolderAtClosure: ((CloudPath) -> Promise<Void>)?

	func deleteFolder(at cloudPath: CloudPath) -> Promise<Void> {
		deleteFolderAtCallsCount += 1
		deleteFolderAtReceivedCloudPath = cloudPath
		deleteFolderAtReceivedInvocations.append(cloudPath)
		return deleteFolderAtClosure.map({ $0(cloudPath) }) ?? deleteFolderAtReturnValue
	}

	// MARK: - moveFile

	var moveFileFromToCallsCount = 0
	var moveFileFromToCalled: Bool {
		moveFileFromToCallsCount > 0
	}

	var moveFileFromToReceivedArguments: (sourceCloudPath: CloudPath, targetCloudPath: CloudPath)?
	var moveFileFromToReceivedInvocations: [(sourceCloudPath: CloudPath, targetCloudPath: CloudPath)] = []
	var moveFileFromToReturnValue: Promise<Void>!
	var moveFileFromToClosure: ((CloudPath, CloudPath) -> Promise<Void>)?

	func moveFile(from sourceCloudPath: CloudPath, to targetCloudPath: CloudPath) -> Promise<Void> {
		moveFileFromToCallsCount += 1
		moveFileFromToReceivedArguments = (sourceCloudPath: sourceCloudPath, targetCloudPath: targetCloudPath)
		moveFileFromToReceivedInvocations.append((sourceCloudPath: sourceCloudPath, targetCloudPath: targetCloudPath))
		return moveFileFromToClosure.map({ $0(sourceCloudPath, targetCloudPath) }) ?? moveFileFromToReturnValue
	}

	// MARK: - moveFolder

	var moveFolderFromToCallsCount = 0
	var moveFolderFromToCalled: Bool {
		moveFolderFromToCallsCount > 0
	}

	var moveFolderFromToReceivedArguments: (sourceCloudPath: CloudPath, targetCloudPath: CloudPath)?
	var moveFolderFromToReceivedInvocations: [(sourceCloudPath: CloudPath, targetCloudPath: CloudPath)] = []
	var moveFolderFromToReturnValue: Promise<Void>!
	var moveFolderFromToClosure: ((CloudPath, CloudPath) -> Promise<Void>)?

	func moveFolder(from sourceCloudPath: CloudPath, to targetCloudPath: CloudPath) -> Promise<Void> {
		moveFolderFromToCallsCount += 1
		moveFolderFromToReceivedArguments = (sourceCloudPath: sourceCloudPath, targetCloudPath: targetCloudPath)
		moveFolderFromToReceivedInvocations.append((sourceCloudPath: sourceCloudPath, targetCloudPath: targetCloudPath))
		return moveFolderFromToClosure.map({ $0(sourceCloudPath, targetCloudPath) }) ?? moveFolderFromToReturnValue
	}
}

// swiftlint:enable all