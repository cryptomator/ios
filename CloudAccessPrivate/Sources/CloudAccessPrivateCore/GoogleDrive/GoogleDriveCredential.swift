//
//  GoogleDriveCredential.swift
//  CloudAccessPrivate-Core
//
//  Created by Philipp Schmid on 22.09.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import AppAuthCore
import Foundation
import GoogleAPIClientForREST_Drive
import GTMAppAuth
import Promises

public enum GoogleDriveCredentialError: Error {
	case notAuthenticated
	case noUsername
}

public class GoogleDriveCredential {
	let keychainItemPrefix = "GoogleDriveAuth"
	private let keychainItemName: String
	public let tokenUid: String
	public var authorization: GTMAppAuthFetcherAuthorization?
	public let driveService: GTLRDriveService
	public var isAuthorized: Bool {
		authorization?.canAuthorize() ?? false
	}

	public init(with tokenUid: String) {
		self.tokenUid = tokenUid
		self.keychainItemName = keychainItemPrefix + "-" + tokenUid
		self.authorization = GTMAppAuthFetcherAuthorization(fromKeychainForName: keychainItemName)
		self.driveService = GTLRDriveService()
		driveService.serviceUploadChunkSize = GoogleDriveCloudProvider.maximumUploadFetcherChunkSize
		driveService.isRetryEnabled = true
		driveService.retryBlock = { _, suggestedWillRetry, fetchError in
			if let fetchError = fetchError as NSError? {
				if fetchError.domain != kGTMSessionFetcherStatusDomain || fetchError.code != GoogleDriveConstants.googleDriveErrorCodeForbidden {
					return suggestedWillRetry
				}
				guard let data = fetchError.userInfo["data"] as? Data, let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any], let error = json["error"] as? [String: Any] else {
					return suggestedWillRetry
				}
				let googleDriveError = GTLRErrorObject(json: error)
				guard let errorItem = googleDriveError.errors?.first else {
					return suggestedWillRetry
				}
				return errorItem.domain == GoogleDriveConstants.googleDriveErrorDomainUsageLimits && (errorItem.reason == GoogleDriveConstants.googleDriveErrorReasonUserRateLimitExceeded || errorItem.reason == GoogleDriveConstants.googleDriveErrorReasonRateLimitExceeded)
			}
			return suggestedWillRetry
		}
		driveService.fetcherService.configurationBlock = { _, configuration in
			configuration.sharedContainerIdentifier = CryptomatorConstants.appGroupName
		}
		let bundleId = Bundle.main.bundleIdentifier ?? ""
		let configuration = URLSessionConfiguration.background(withIdentifier: "Crytomator-GoogleDriveSession-\(tokenUid)-\(bundleId)")
		configuration.sharedContainerIdentifier = CryptomatorConstants.appGroupName
		driveService.fetcherService.configuration = configuration
		driveService.fetcherService.isRetryEnabled = true
		driveService.fetcherService.retryBlock = { suggestedWillRetry, error, response in
			if let error = error as NSError? {
				if error.domain == kGTMSessionFetcherStatusDomain, error.code == GoogleDriveConstants.googleDriveErrorCodeForbidden {
					return response(true)
				}
			}
			response(suggestedWillRetry)
		}
		driveService.fetcherService.unusedSessionTimeout = 0
		driveService.fetcherService.reuseSession = true
		driveService.authorizer = authorization
	}

	public func save(authState: OIDAuthState) {
		authorization = GTMAppAuthFetcherAuthorization(authState: authState)
		driveService.authorizer = authorization
		if let authorization = authorization {
			GTMAppAuthFetcherAuthorization.save(authorization, toKeychainForName: keychainItemName)
		}
	}

	public func getUsername() throws -> String {
		guard isAuthorized else {
			throw GoogleDriveCredentialError.notAuthenticated
		}
		guard let userEmail = authorization?.userEmail else {
			throw GoogleDriveCredentialError.noUsername
		}
		return userEmail
	}

	public func deauthenticate() {
		GTMAppAuthFetcherAuthorization.removeFromKeychain(forName: keychainItemName)
		driveService.fetcherService.resetSession()
		authorization = nil
		driveService.authorizer = nil
	}
}
