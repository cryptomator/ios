//
//  GoogleDriveConstants.swift
//  CloudAccessPrivate-Core
//
//  Created by Philipp Schmid on 29.10.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Foundation
struct GoogleDriveConstants {
	static let rootFolderId = "root"
	static let folderMimeType = "application/vnd.google-apps.folder"
	static let unknownMimeType = "application/octet-stream"
	static let googleDriveErrorCodeFileNotFound = 404
	static let googleDriveErrorCodeForbidden = 403
	static let googleDriveErrorCodeInvalidCredentials = 401
	static let googleDriveErrorDomainUsageLimits = "usageLimits"
	static let googleDriveErrorReasonUserRateLimitExceeded = "userRateLimitExceeded"
	static let googleDriveErrorReasonRateLimitExceeded = "rateLimitExceeded"
}
