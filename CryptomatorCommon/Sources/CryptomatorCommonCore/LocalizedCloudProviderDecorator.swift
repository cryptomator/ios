//
//  LocalizedCloudProviderDecorator.swift
//  CryptomatorCommonCore
//
//  Created by Tobias Hagemann on 19.08.21.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation
import Promises

public class LocalizedCloudProviderDecorator: CloudProvider {
	// swiftlint:disable:next weak_delegate
	public let delegate: CloudProvider

	public init(delegate: CloudProvider) {
		self.delegate = delegate
	}

	public func fetchItemMetadata(at cloudPath: CloudPath) -> Promise<CloudItemMetadata> {
		return delegate.fetchItemMetadata(at: cloudPath).recover { error -> CloudItemMetadata in
			if let error = error as? CloudProviderError {
				throw LocalizedCloudProviderError.convertToLocalized(error, cloudPath: cloudPath)
			} else {
				throw error
			}
		}
	}

	public func fetchItemList(forFolderAt cloudPath: CloudPath, withPageToken pageToken: String?) -> Promise<CloudItemList> {
		return delegate.fetchItemList(forFolderAt: cloudPath, withPageToken: pageToken).recover { error -> CloudItemList in
			if let error = error as? CloudProviderError {
				throw LocalizedCloudProviderError.convertToLocalized(error, cloudPath: cloudPath)
			} else {
				throw error
			}
		}
	}

	public func downloadFile(from cloudPath: CloudPath, to localURL: URL) -> Promise<Void> {
		return delegate.downloadFile(from: cloudPath, to: localURL).recover { error -> Void in
			if let error = error as? CloudProviderError {
				switch error {
				case .itemAlreadyExists:
					throw LocalizedCloudProviderError.convertToLocalized(error, cloudPath: CloudPath(localURL.path))
				default:
					throw LocalizedCloudProviderError.convertToLocalized(error, cloudPath: cloudPath)
				}
			} else {
				throw error
			}
		}
	}

	public func uploadFile(from localURL: URL, to cloudPath: CloudPath, replaceExisting: Bool) -> Promise<CloudItemMetadata> {
		return delegate.uploadFile(from: localURL, to: cloudPath, replaceExisting: replaceExisting).recover { error -> CloudItemMetadata in
			if let error = error as? CloudProviderError {
				switch error {
				case .itemNotFound, .itemTypeMismatch:
					throw LocalizedCloudProviderError.convertToLocalized(error, cloudPath: CloudPath(localURL.path))
				default:
					throw LocalizedCloudProviderError.convertToLocalized(error, cloudPath: cloudPath)
				}
			} else {
				throw error
			}
		}
	}

	public func createFolder(at cloudPath: CloudPath) -> Promise<Void> {
		return delegate.createFolder(at: cloudPath).recover { error -> Void in
			if let error = error as? CloudProviderError {
				throw LocalizedCloudProviderError.convertToLocalized(error, cloudPath: cloudPath)
			} else {
				throw error
			}
		}
	}

	public func deleteFile(at cloudPath: CloudPath) -> Promise<Void> {
		return delegate.deleteFile(at: cloudPath).recover { error -> Void in
			if let error = error as? CloudProviderError {
				throw LocalizedCloudProviderError.convertToLocalized(error, cloudPath: cloudPath)
			} else {
				throw error
			}
		}
	}

	public func deleteFolder(at cloudPath: CloudPath) -> Promise<Void> {
		return delegate.deleteFolder(at: cloudPath).recover { error -> Void in
			if let error = error as? CloudProviderError {
				throw LocalizedCloudProviderError.convertToLocalized(error, cloudPath: cloudPath)
			} else {
				throw error
			}
		}
	}

	public func moveFile(from sourceCloudPath: CloudPath, to targetCloudPath: CloudPath) -> Promise<Void> {
		return delegate.moveFile(from: sourceCloudPath, to: targetCloudPath).recover { error -> Void in
			if let error = error as? CloudProviderError {
				switch error {
				case .itemAlreadyExists, .parentFolderDoesNotExist:
					throw LocalizedCloudProviderError.convertToLocalized(error, cloudPath: targetCloudPath)
				default:
					throw LocalizedCloudProviderError.convertToLocalized(error, cloudPath: sourceCloudPath)
				}
			} else {
				throw error
			}
		}
	}

	public func moveFolder(from sourceCloudPath: CloudPath, to targetCloudPath: CloudPath) -> Promise<Void> {
		return delegate.moveFolder(from: sourceCloudPath, to: targetCloudPath).recover { error -> Void in
			if let error = error as? CloudProviderError {
				switch error {
				case .itemAlreadyExists, .parentFolderDoesNotExist:
					throw LocalizedCloudProviderError.convertToLocalized(error, cloudPath: targetCloudPath)
				default:
					throw LocalizedCloudProviderError.convertToLocalized(error, cloudPath: sourceCloudPath)
				}
			} else {
				throw error
			}
		}
	}
}
