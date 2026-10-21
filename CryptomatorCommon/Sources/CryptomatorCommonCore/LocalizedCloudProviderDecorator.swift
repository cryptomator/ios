//
//  LocalizedCloudProviderDecorator.swift
//  CryptomatorCommonCore
//
//  Created by Tobias Hagemann on 19.08.21.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation

public final class LocalizedCloudProviderDecorator: CloudProvider, Sendable {
	// swiftlint:disable:next weak_delegate
	public let delegate: CloudProvider

	public init(delegate: CloudProvider) {
		self.delegate = delegate
	}

	@concurrent
	public func fetchItemMetadata(at cloudPath: CloudPath) async throws -> CloudItemMetadata {
		do {
			return try await delegate.fetchItemMetadata(at: cloudPath)
		} catch let error as CloudProviderError {
			throw LocalizedCloudProviderError.convertToLocalized(error, cloudPath: cloudPath)
		}
	}

	@concurrent
	public func fetchItemList(forFolderAt cloudPath: CloudPath, withPageToken pageToken: String?) async throws -> CloudItemList {
		do {
			return try await delegate.fetchItemList(forFolderAt: cloudPath, withPageToken: pageToken)
		} catch let error as CloudProviderError {
			throw LocalizedCloudProviderError.convertToLocalized(error, cloudPath: cloudPath)
		}
	}

	@concurrent
	public func downloadFile(from cloudPath: CloudPath, to localURL: URL, progress: Progress?, onTaskCreation: (@concurrent @Sendable (URLSessionDownloadTask) async -> Void)?) async throws -> CloudItemMetadata {
		do {
			return try await delegate.downloadFile(from: cloudPath, to: localURL, progress: progress, onTaskCreation: onTaskCreation)
		} catch let error as CloudProviderError {
			switch error {
			case .itemAlreadyExists:
				throw LocalizedCloudProviderError.convertToLocalized(error, cloudPath: CloudPath(localURL.path))
			default:
				throw LocalizedCloudProviderError.convertToLocalized(error, cloudPath: cloudPath)
			}
		}
	}

	@concurrent
	public func uploadFile(from localURL: URL, to cloudPath: CloudPath, replaceExisting: Bool, progress: Progress?, onTaskCreation: (@concurrent @Sendable (URLSessionUploadTask) async -> Void)?) async throws -> CloudItemMetadata {
		do {
			return try await delegate.uploadFile(from: localURL, to: cloudPath, replaceExisting: replaceExisting, progress: progress, onTaskCreation: onTaskCreation)
		} catch let error as CloudProviderError {
			switch error {
			case .itemNotFound, .itemTypeMismatch:
				throw LocalizedCloudProviderError.convertToLocalized(error, cloudPath: CloudPath(localURL.path))
			default:
				throw LocalizedCloudProviderError.convertToLocalized(error, cloudPath: cloudPath)
			}
		}
	}

	@concurrent
	public func createFolder(at cloudPath: CloudPath) async throws {
		do {
			try await delegate.createFolder(at: cloudPath)
		} catch let error as CloudProviderError {
			throw LocalizedCloudProviderError.convertToLocalized(error, cloudPath: cloudPath)
		}
	}

	@concurrent
	public func deleteFile(at cloudPath: CloudPath) async throws {
		do {
			try await delegate.deleteFile(at: cloudPath)
		} catch let error as CloudProviderError {
			throw LocalizedCloudProviderError.convertToLocalized(error, cloudPath: cloudPath)
		}
	}

	@concurrent
	public func deleteFolder(at cloudPath: CloudPath) async throws {
		do {
			try await delegate.deleteFolder(at: cloudPath)
		} catch let error as CloudProviderError {
			throw LocalizedCloudProviderError.convertToLocalized(error, cloudPath: cloudPath)
		}
	}

	@concurrent
	public func moveFile(from sourceCloudPath: CloudPath, to targetCloudPath: CloudPath) async throws {
		do {
			try await delegate.moveFile(from: sourceCloudPath, to: targetCloudPath)
		} catch let error as CloudProviderError {
			switch error {
			case .itemAlreadyExists, .parentFolderDoesNotExist:
				throw LocalizedCloudProviderError.convertToLocalized(error, cloudPath: targetCloudPath)
			default:
				throw LocalizedCloudProviderError.convertToLocalized(error, cloudPath: sourceCloudPath)
			}
		}
	}

	@concurrent
	public func moveFolder(from sourceCloudPath: CloudPath, to targetCloudPath: CloudPath) async throws {
		do {
			try await delegate.moveFolder(from: sourceCloudPath, to: targetCloudPath)
		} catch let error as CloudProviderError {
			switch error {
			case .itemAlreadyExists, .parentFolderDoesNotExist:
				throw LocalizedCloudProviderError.convertToLocalized(error, cloudPath: targetCloudPath)
			default:
				throw LocalizedCloudProviderError.convertToLocalized(error, cloudPath: sourceCloudPath)
			}
		}
	}
}
