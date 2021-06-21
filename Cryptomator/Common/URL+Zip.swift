//
//  URL+Zip.swift
//  Cryptomator
//
//  Created by Tobias Hagemann on 07.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation

enum ZipError: Error {
	case unexpectedSourceURL
}

extension URL {
	/**
	 Based on: <https://gist.github.com/algal/2880f79061197cc54d918631f252cd75>
	 */
	func zipFolder(toFileAt dstURL: URL) throws {
		var isDirectory: ObjCBool = false
		guard isFileURL, FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue == true else {
			throw ZipError.unexpectedSourceURL
		}
		var readError: NSError?
		var copyError: Error?
		NSFileCoordinator().coordinate(readingItemAt: self, options: NSFileCoordinator.ReadingOptions.forUploading, error: &readError) { zippedURL in
			do {
				// `zippedURL` is only valid for the duration of the block, so it needs to be copied out
				try FileManager.default.copyItem(at: zippedURL, to: dstURL)
			} catch {
				copyError = error
			}
		}
		if let readError = readError {
			throw readError
		} else if let copyError = copyError {
			throw copyError
		}
	}
}
