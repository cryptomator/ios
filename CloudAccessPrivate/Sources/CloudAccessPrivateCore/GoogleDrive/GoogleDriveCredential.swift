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
	public var authorization: GTMAppAuthFetcherAuthorization?
	public let driveService: GTLRDriveService
	public var isAuthorized: Bool {
		authorization?.canAuthorize() ?? false
	}

	public init(with tokenUid: String) {
		self.keychainItemName = keychainItemPrefix + "-" + tokenUid
		self.authorization = GTMAppAuthFetcherAuthorization(fromKeychainForName: keychainItemName)
		self.driveService = GTLRDriveService()
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
		authorization = nil
		driveService.authorizer = nil
	}
}
