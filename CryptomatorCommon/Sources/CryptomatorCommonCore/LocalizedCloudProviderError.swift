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
			return String(format: LocalizedString.getValue("cloudProvider.error.itemNotFound"), cloudPath.lastPathComponent)
		case let .itemAlreadyExists(cloudPath: cloudPath):
			return String(format: LocalizedString.getValue("cloudProvider.error.itemAlreadyExists"), cloudPath.lastPathComponent)
		case let .itemTypeMismatch(cloudPath: cloudPath):
			return String(format: LocalizedString.getValue("cloudProvider.error.itemTypeMismatch"), cloudPath.lastPathComponent)
		case let .parentFolderDoesNotExist(cloudPath: cloudPath):
			return String(format: LocalizedString.getValue("cloudProvider.error.parentFolderDoesNotExist"), cloudPath.deletingLastPathComponent().lastPathComponent)
		case .pageTokenInvalid:
			return LocalizedString.getValue("cloudProvider.error.pageTokenInvalid")
		case .quotaInsufficient:
			return LocalizedString.getValue("cloudProvider.error.quotaInsufficient")
		case .unauthorized:
			return LocalizedString.getValue("cloudProvider.error.unauthorized")
		case .noInternetConnection:
			return LocalizedString.getValue("cloudProvider.error.noInternetConnection")
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
