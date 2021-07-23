//
//  LocalizedCloudProviderError.swift
//  CryptomatorCommonCore
//
//  Created by Tobias Hagemann on 19.07.21.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation

public enum LocalizedCloudProviderError: LocalizedError {
	case itemNotFound(cloudPath: CloudPath)
	case itemAlreadyExists(cloudPath: CloudPath)
	case itemTypeMismatch(cloudPath: CloudPath)
	case parentFolderDoesNotExist(cloudPath: CloudPath)
	case pageTokenInvalid
	case quotaInsufficient
	case unauthorized
	case noInternetConnection

	public var errorDescription: String? {
		switch self {
		case let .itemNotFound(cloudPath: cloudPath):
			return String(format: NSLocalizedString("cloudProvider.error.itemNotFound", comment: ""), cloudPath.lastPathComponent)
		case let .itemAlreadyExists(cloudPath: cloudPath):
			return String(format: NSLocalizedString("cloudProvider.error.itemAlreadyExists", comment: ""), cloudPath.lastPathComponent)
		case let .itemTypeMismatch(cloudPath: cloudPath):
			return String(format: NSLocalizedString("cloudProvider.error.itemTypeMismatch", comment: ""), cloudPath.lastPathComponent)
		case let .parentFolderDoesNotExist(cloudPath: cloudPath):
			return String(format: NSLocalizedString("cloudProvider.error.parentFolderDoesNotExist", comment: ""), cloudPath.deletingLastPathComponent().lastPathComponent)
		case .pageTokenInvalid:
			return NSLocalizedString("cloudProvider.error.pageTokenInvalid", comment: "")
		case .quotaInsufficient:
			return NSLocalizedString("cloudProvider.error.quotaInsufficient", comment: "")
		case .unauthorized:
			return NSLocalizedString("cloudProvider.error.unauthorized", comment: "")
		case .noInternetConnection:
			return NSLocalizedString("cloudProvider.error.noInternetConnection", comment: "")
		}
	}

	public static func convertToLocalized(_ error: CloudProviderError, cloudPath: CloudPath) -> LocalizedCloudProviderError {
		switch error {
		case .itemNotFound:
			return .itemNotFound(cloudPath: cloudPath)
		case .itemAlreadyExists:
			return .itemAlreadyExists(cloudPath: cloudPath)
		case .itemTypeMismatch:
			return .itemTypeMismatch(cloudPath: cloudPath)
		case .parentFolderDoesNotExist:
			return .parentFolderDoesNotExist(cloudPath: cloudPath)
		case .pageTokenInvalid:
			return .pageTokenInvalid
		case .quotaInsufficient:
			return .quotaInsufficient
		case .unauthorized:
			return .unauthorized
		case .noInternetConnection:
			return .noInternetConnection
		}
	}
}
