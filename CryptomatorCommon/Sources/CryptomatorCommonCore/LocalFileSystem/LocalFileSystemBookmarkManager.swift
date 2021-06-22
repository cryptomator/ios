//
//  LocalFileSystemBookmarkManager.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 23.10.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Foundation

public enum LocalFileSystemBookmarkManager {
	public static func getBookmarkedRootURL(for accountUID: String) throws -> URL? {
		guard let bookmarkData = CryptomatorKeychain.localFileSystem.getAsData(accountUID) else {
			return nil
		}
		var isStale = false
		let url = try URL(resolvingBookmarkData: bookmarkData, bookmarkDataIsStale: &isStale)
		if isStale {
			try saveBookmarkForRootURL(url, for: accountUID)
		}
		return url
	}

	public static func saveBookmarkForRootURL(_ url: URL, for accountUID: String) throws {
		let stopAccess = url.startAccessingSecurityScopedResource()
		defer {
			if stopAccess {
				url.stopAccessingSecurityScopedResource()
			}
		}
		let bookmarkData = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
		try CryptomatorKeychain.localFileSystem.set(accountUID, value: bookmarkData)
	}

	public static func removeBookmarkedRootURL(for accountUID: String) throws {
		try CryptomatorKeychain.localFileSystem.delete(accountUID)
	}
}
